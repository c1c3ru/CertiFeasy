import 'dart:typed_data';

import 'package:certifeasy/core/utils/participant_excel_reader.dart';
import 'package:certifeasy/core/utils/participant_table_parser.dart';
import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void writeRows(Excel workbook, String sheetName, List<List<String>> rows) {
  final sheet = workbook[sheetName];
  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    for (var columnIndex = 0;
        columnIndex < rows[rowIndex].length;
        columnIndex++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
        TextCellValue(rows[rowIndex][columnIndex]),
      );
    }
  }
}

Future<ParticipantTable> decode(Excel workbook) async {
  final bytes = workbook.save()!;
  final rows = await ParticipantExcelReader.readRows(Uint8List.fromList(bytes));
  return ParticipantTableParser.parseRows(rows);
}

void main() {
  test('importa XLSX de apresentação acadêmica sem horas', () async {
    final workbook = Excel.createExcel();
    writeRows(workbook, 'Sheet1', [
      [
        'Nome',
        'Orientador(a)',
        'Título do trabalho',
        'Evento',
        'Data',
        'E-mail',
        'E-mail do orientador',
      ],
      [
        'OLIVEIRA, Ana',
        'RODRIGUES, Profa. Marta',
        'ANÁLISE DE VIDEOAULAS DE QUÍMICA',
        'II Mostra Científica',
        '9-out.',
        'ana@example.com',
        'Profa. Marta <marta@ifce.example>',
      ],
    ]);

    final imported = await decode(workbook);

    expect(imported.mappedData, hasLength(1));
    expect(imported.mappedData.single['nome'], 'OLIVEIRA, Ana');
    expect(imported.mappedData.single['orientador'],
        'RODRIGUES, Profa. Marta');
    expect(imported.mappedData.single['nome_trabalho'],
        'ANÁLISE DE VIDEOAULAS DE QUÍMICA');
    expect(imported.mappedData.single['data'], '9-out.');
    expect(imported.mappedData.single['email_orientador'],
        'marta@ifce.example');
    expect(imported.mappedData.single['horas'], '');
  });

  test('importa XLSX tradicional e preserva a coluna horas', () async {
    final workbook = Excel.createExcel();
    writeRows(workbook, 'Sheet1', [
      ['nome', 'evento', 'data', 'horas', 'email'],
      ['Ana', 'Curso', '10/10/2026', '16', 'ana@example.com'],
    ]);

    final imported = await decode(workbook);
    expect(imported.mappedData.single['horas'].toString(), '16');
  });

  test('procura primeira aba válida e ignora aba de instruções', () async {
    final workbook = Excel.createExcel();
    writeRows(workbook, 'Sheet1', [
      ['Instruções'],
      ['Escolha a aba Participantes'],
    ]);
    writeRows(workbook, 'Participantes', [
      ['nome', 'evento', 'data', 'horas', 'email'],
      ['Ana', 'Curso', '10/10/2026', '16', 'ana@example.com'],
    ]);

    final imported = await decode(workbook);
    expect(imported.mappedData.single['nome'], 'Ana');
  });

  test('não importa XLSX tradicional sem horas', () async {
    final workbook = Excel.createExcel();
    writeRows(workbook, 'Sheet1', [
      ['nome', 'evento', 'data', 'email'],
      ['Ana', 'Curso', '10/10/2026', 'ana@example.com'],
    ]);

    await expectLater(
      decode(workbook),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'erro',
        contains('horas'),
      )),
    );
  });

  test('planilha inválida retorna erro, sem inventar registros', () async {
    await expectLater(
      ParticipantExcelReader.readRows(Uint8List.fromList([1, 2, 3, 4])),
      throwsA(isA<FormatException>()),
    );
  });
}
