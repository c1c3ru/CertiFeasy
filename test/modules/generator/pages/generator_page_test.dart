import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:certifeasy/modules/generator/pages/generator_page.dart';
import 'package:certifeasy/modules/generator/blocs/generator_bloc.dart';
import 'package:certifeasy/modules/generator/blocs/generator_event.dart';
import 'package:certifeasy/modules/generator/blocs/generator_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest(GeneratorBloc bloc) {
    return MaterialApp(
      home: BlocProvider<GeneratorBloc>.value(
        value: bloc,
        child: const GeneratorPage(),
      ),
    );
  }

  testWidgets('GeneratorPage renders basic layout correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final bloc = GeneratorBloc();
    await tester.pumpWidget(createWidgetUnderTest(bloc));
    await tester.pumpAndSettle();

    // Verify tabs
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Texto & Variáveis'), findsOneWidget);
    expect(find.text('Aparência'), findsOneWidget);
    expect(find.text('E-mails'), findsOneWidget);
    
    // Default tab is 0, so upload content should be visible
    expect(find.text('Template Frente'), findsOneWidget);
    expect(find.text('Arquivo CSV / Excel'), findsOneWidget);
    
    bloc.close();
  });

  testWidgets('Displays empty state message on other tabs if no data', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final bloc = GeneratorBloc();
    await tester.pumpWidget(createWidgetUnderTest(bloc));
    await tester.pumpAndSettle();

    // Tap on Text & Variables tab (index 1)
    await tester.tap(find.text('Texto & Variáveis').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // allow snackbar to show

    expect(find.text('Faça o upload do CSV e da Imagem base para desbloquear esta aba.'), findsOneWidget);

    bloc.close();
  });
  
  testWidgets('usa campos acadêmicos do arquivo sem formulário redundante',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final bloc = GeneratorBloc();
    addTearDown(bloc.close);
    await tester.pumpWidget(createWidgetUnderTest(bloc));
    await tester.pumpAndSettle();

    bloc.add(LoadFilesEvent(
      csvContent: 'Nome;Orientador(a);Título do trabalho;Evento;Data;E-mail;E-mail do orientador\n'
          'Ana;Prof. Carlos Lima;Inovação no Ensino;Mostra;9-out.;ana@example.com;carlos@example.com',
    ));
    await tester.pumpAndSettle();

    // Todos os valores vêm da planilha: nenhuma segunda digitação é necessária.
    expect(find.byKey(const Key('academic-info-editor')), findsNothing);
    expect(find.byKey(const Key('academic-orientador')), findsNothing);
    expect(find.byKey(const Key('academic-email-orientador')), findsNothing);
    expect(find.byKey(const Key('academic-nome-trabalho')), findsNothing);
    expect(find.text('Colunas detectadas:'), findsOneWidget);
    expect(find.text('{orientador}'), findsOneWidget);
    expect(find.text('{nome_trabalho}'), findsOneWidget);
    expect(find.text('{email_orientador}'), findsOneWidget);

    final state = bloc.state as GeneratorLoaded;
    expect(state.mappedData.single['orientador'], 'Prof. Carlos Lima');
    expect(state.mappedData.single['nome_trabalho'], 'Inovação no Ensino');
    expect(state.mappedData.single['email_orientador'], 'carlos@example.com');
    expect(state.mappedData.single['horas'], '');
  });

  testWidgets('aviso de privacidade é discreto e aparece só na aba E-mails',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final bloc = GeneratorBloc();
    addTearDown(bloc.close);
    await tester.pumpWidget(createWidgetUnderTest(bloc));
    await tester.pumpAndSettle();

    // Não há aviso na página inicial nem login Google obrigatório.
    expect(find.byKey(const Key('email-privacy-notice')), findsNothing);

    final Uint8List image = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='
    );
    bloc.add(LoadFilesEvent(
      csvContent: 'nome;evento;data;horas;email\nAna;Feira;2026;4;ana@example.com',
      imageBytes: image,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('E-mails').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('email-privacy-notice')), findsOneWidget);
    expect(find.text('Por que pedimos seu e-mail?'), findsOneWidget);
    expect(find.byKey(const Key('email-privacy-details')), findsNothing);

    await tester.ensureVisible(
      find.byKey(const Key('email-privacy-details-toggle')),
    );
    await tester.tap(find.byKey(const Key('email-privacy-details-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('email-privacy-details')), findsOneWidget);
  });

  testWidgets('Shows variable chips when CSV is loaded', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final bloc = GeneratorBloc();
    
    await tester.pumpWidget(createWidgetUnderTest(bloc));
    await tester.pumpAndSettle();
    
    // Wait for initial email config load to finish so it's in GeneratorLoaded
    await tester.pumpAndSettle();

    final Uint8List dummyImageBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='
    );
    
    // Simulate CSV and image load
    bloc.add(LoadFilesEvent(
      csvContent: 'nome;evento;data;horas;email;orientador;email_orientador;nome_trabalho\nTeste;Tech;2023;10;t@t.com;Prof. Ana;ana@ifce.edu.br;Pesquisa em IA',
      imageBytes: dummyImageBytes,
    ));
    
    await tester.pumpAndSettle();

    // Verify it's not in unknown state
    expect(find.text('Estado desconhecido'), findsNothing);

    // Change to tab 1 to see chips
    await tester.tap(find.text('Texto & Variáveis').last);
    await tester.pumpAndSettle();

    // Verify chips in variables tab
    expect(find.text('{nome}'), findsOneWidget);
    expect(find.text('{horas}'), findsOneWidget);
    expect(find.text('{orientador}'), findsOneWidget);
    expect(find.text('{email_orientador}'), findsOneWidget);
    expect(find.text('{nome_trabalho}'), findsOneWidget);

    bloc.close();
  });
}
