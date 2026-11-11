import 'package:certifeasy/core/utils/rich_text_markup.dart';
import 'package:certifeasy/modules/generator/blocs/generator_bloc.dart';
import 'package:certifeasy/modules/generator/blocs/generator_event.dart';
import 'package:certifeasy/modules/generator/blocs/generator_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('cada trabalho mantém os dados importados do arquivo, sem edição extra',
      () async {
    final bloc = GeneratorBloc();
    addTearDown(bloc.close);

    const tsv =
        'Nome\tOrientador(a)\tTítulo do trabalho\tEvento\tData\tE-mail\tE-mail do orientador\n'
        'Ana\tProf. Carlos\tInovação no Ensino\tMostra\t9-out.\tana@example.com\tcarlos@example.com\n'
        'Bia\tProfa. Marta\tTecnologia na Escola\tMostra\t9-out.\tbia@example.com\tmarta@example.com';

    final loaded = bloc.stream
        .where((state) =>
            state is GeneratorLoaded && state.mappedData.length == 2)
        .cast<GeneratorLoaded>()
        .first;
    bloc.add(LoadFilesEvent(csvContent: tsv));
    final state = await loaded;

    expect(state.mappedData, hasLength(2));
    expect(state.csvHeaders, containsAll([
      'nome', 'orientador', 'nome_trabalho', 'email_orientador', 'horas',
    ]));
    expect(state.mappedData.first['orientador'], 'Prof. Carlos');
    expect(state.mappedData.last['orientador'], 'Profa. Marta');
    expect(state.mappedData.first['nome_trabalho'], 'Inovação no Ensino');
    expect(state.mappedData.last['nome_trabalho'], 'Tecnologia na Escola');
    expect(state.mappedData.first['email_orientador'], 'carlos@example.com');
    expect(state.mappedData.last['email_orientador'], 'marta@example.com');
    expect(state.mappedData.first['horas'], '');

    const template = '{nome} apresentou {nome_trabalho} sob orientação de {orientador}.';
    expect(
      stripMarkup(fillTemplate(template, state.mappedData.first)),
      'Ana apresentou Inovação no Ensino sob orientação de Prof. Carlos.',
    );
    expect(
      stripMarkup(fillTemplate(template, state.mappedData.last)),
      'Bia apresentou Tecnologia na Escola sob orientação de Profa. Marta.',
    );
  });

  test('novo upload substitui os dados anteriores, sem formular preenchimento',
      () async {
    final bloc = GeneratorBloc();
    addTearDown(bloc.close);

    final firstLoad = bloc.stream
        .where((s) => s is GeneratorLoaded && s.mappedData.isNotEmpty)
        .cast<GeneratorLoaded>()
        .first;
    bloc.add(LoadFilesEvent(
      csvContent: 'nome;evento;data;horas;email\n'
          'Ana;Curso;2026;8;ana@example.com',
    ));
    await firstLoad;

    final replaced = bloc.stream
        .where((s) =>
            s is GeneratorLoaded &&
            s.mappedData.isNotEmpty &&
            s.mappedData.first['nome'] == 'Bia')
        .cast<GeneratorLoaded>()
        .first;

    bloc.add(LoadFilesEvent(
      csvContent:
          'Nome;Orientador(a);Título do trabalho;Evento;Data;E-mail;E-mail do orientador\n'
          'Bia;Prof. Carlos;Inovação;Mostra;9-out.;bia@example.com;carlos@example.com',
    ));
    final state = await replaced;

    expect(state.mappedData, hasLength(1));
    expect(state.mappedData.single['nome_trabalho'], 'Inovação');
    expect(state.mappedData.single['orientador'], 'Prof. Carlos');
    expect(state.mappedData.single['horas'], '');
  });
}
