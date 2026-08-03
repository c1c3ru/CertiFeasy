import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:certifeasy/modules/generator/pages/generator_page.dart';
import 'package:certifeasy/modules/generator/blocs/generator_bloc.dart';
import 'package:certifeasy/modules/generator/blocs/generator_event.dart';
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
    expect(find.text('Arquivo CSV'), findsOneWidget);
    
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
      csvContent: 'nome;evento;data;horas;email\nTeste;Tech;2023;10;t@t.com',
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

    bloc.close();
  });
}
