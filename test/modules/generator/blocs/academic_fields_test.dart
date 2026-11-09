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

  test('permite editar três campos em CSV legado sem alterar outra linha', () async {
    final bloc = GeneratorBloc();
    addTearDown(bloc.close);

    const csv = 'nome;evento;data;horas;email\n'
        'Ana;Mostra;2026;8;ana@exemplo.com\n'
        'Bia;Mostra;2026;8;bia@exemplo.com';

    final firstLoad = bloc.stream
        .where((s) => s is GeneratorLoaded && s.mappedData.length == 2)
        .cast<GeneratorLoaded>()
        .first;
    bloc.add(LoadFilesEvent(csvContent: csv));
    final initial = await firstLoad;
    expect(initial.csvHeaders, ['nome', 'evento', 'data', 'horas', 'email']);

    Future<GeneratorLoaded> update(
      int rowIndex,
      AcademicField field,
      String value,
    ) {
      final next = bloc.stream
          .where((s) =>
              s is GeneratorLoaded &&
              s.mappedData[rowIndex][field.column] == value)
          .cast<GeneratorLoaded>()
          .first;
      bloc.add(UpdateAcademicFieldEvent(
        rowIndex: rowIndex,
        field: field,
        value: value,
      ));
      return next;
    }

    await update(0, AcademicField.orientador, 'Prof. João');
    await update(0, AcademicField.emailOrientador, 'joao@instituicao.edu.br');
    final modified = await update(
      0,
      AcademicField.nomeTrabalho,
      'Pesquisa Aplicada',
    );

    expect(modified.csvHeaders, [
      'nome', 'evento', 'data', 'horas', 'email',
      'orientador', 'email_orientador', 'nome_trabalho',
    ]);
    expect(modified.csvData.first, modified.csvHeaders);
    expect(modified.csvData[1][5], 'Prof. João');
    expect(modified.csvData[1][6], 'joao@instituicao.edu.br');
    expect(modified.csvData[1][7], 'Pesquisa Aplicada');
    expect(modified.mappedData[1].containsKey('orientador'), isFalse);

    expect(
      stripMarkup(fillTemplate(
        'Título: {nome_trabalho} — {orientador} ({email_orientador})',
        modified.mappedData.first,
      )),
      'Título: Pesquisa Aplicada — Prof. João (joao@instituicao.edu.br)',
    );

    final otherRow = await update(
      1,
      AcademicField.orientador,
      'Profa. Marta',
    );
    expect(otherRow.mappedData.first['orientador'], 'Prof. João');
    expect(otherRow.mappedData.last['orientador'], 'Profa. Marta');
    expect(otherRow.csvData[2][5], 'Profa. Marta');
  });

  test('atualiza valores importados, incluindo strings vazias', () async {
    final bloc = GeneratorBloc();
    addTearDown(bloc.close);
    final loaded = bloc.stream
        .where((s) => s is GeneratorLoaded && s.mappedData.isNotEmpty)
        .cast<GeneratorLoaded>()
        .first;
    bloc.add(LoadFilesEvent(
      csvContent: 'nome;evento;data;horas;email;orientador;email_orientador;nome_trabalho\n'
          'Ana;Mostra;2026;8;ana@exemplo.com;Prof. Antigo;a@b.com;Título antigo',
    ));
    await loaded;
    final updated = bloc.stream
        .where((s) => s is GeneratorLoaded && s.mappedData[0]['orientador'] == '')
        .cast<GeneratorLoaded>()
        .first;
    bloc.add(UpdateAcademicFieldEvent(
      rowIndex: 0,
      field: AcademicField.orientador,
      value: '',
    ));
    final state = await updated;
    expect(state.mappedData.single['orientador'], '');
    expect(state.mappedData.single['nome_trabalho'], 'Título antigo');
    expect(state.csvHeaders.where((h) => h == 'orientador').length, 1);
  });

  test('novo CSV substitui valores editados anteriormente', () async {
    final bloc = GeneratorBloc();
    addTearDown(bloc.close);
    final initial = bloc.stream
        .where((s) => s is GeneratorLoaded && s.mappedData.isNotEmpty)
        .cast<GeneratorLoaded>()
        .first;
    bloc.add(LoadFilesEvent(
      csvContent: 'nome;evento;data;horas;email\n'
          'Ana;Mostra;2026;8;ana@exemplo.com',
    ));
    await initial;
    final updated = bloc.stream
        .where((s) => s is GeneratorLoaded && s.mappedData.first['orientador'] == 'Prof. João')
        .cast<GeneratorLoaded>()
        .first;
    bloc.add(UpdateAcademicFieldEvent(
      rowIndex: 0,
      field: AcademicField.orientador,
      value: 'Prof. João',
    ));
    await updated;
    final replaced = bloc.stream
        .where((s) => s is GeneratorLoaded && s.mappedData.first['nome'] == 'Bia')
        .cast<GeneratorLoaded>()
        .first;
    bloc.add(LoadFilesEvent(
      csvContent: 'nome;evento;data;horas;email\n'
          'Bia;Seminário;2026;4;bia@exemplo.com',
    ));
    final state = await replaced;
    expect(state.csvHeaders, isNot(contains('orientador')));
    expect(state.mappedData.single['orientador'], isNull);
  });
}
