import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';

import 'participant_table_parser.dart';

/// Lê pastas de trabalho .xlsx e .xls (Excel 97-2003).
///
/// A primeira aba com cabeçalhos válidos é utilizada. A validação é
/// compartilhada com CSV/TSV, inclusive a exceção acadêmica para "horas".
class ParticipantExcelReader {
  const ParticipantExcelReader._();

  static Future<List<List<dynamic>>> readRows(Uint8List bytes) async {
    try {
      final workbook = await Excel.decodeBytesAsync(bytes);
      String? firstValidationError;

      for (final name in workbook.tables.keys) {
        final sheet = workbook.tables[name]!;
        final rawRows = sheet.rows.map((row) {
          return <dynamic>[
            for (final cell in row)
              _cellText(cell?.value),
          ];
        }).toList();

        if (rawRows.isEmpty) continue;

        // Formatação na planilha pode criar colunas finais vazias.
        // Evita interpretá-las como cabeçalhos sem nome.
        final header = rawRows.first;
        while (header.isNotEmpty &&
            header.last.toString().trim().isEmpty) {
          header.removeLast();
        }
        if (header.isEmpty) continue;

        final columnCount = header.length;
        final rows = [
          for (final row in rawRows)
            row.length > columnCount
                ? row.sublist(0, columnCount)
                : row,
        ];

        try {
          // Ignora abas de instruções e escolhe a primeira com dados válidos.
          ParticipantTableParser.parseRows(rows);
          return rows;
        } on FormatException catch (error) {
          firstValidationError ??= error.message;
        }
      }

      throw FormatException(
        firstValidationError ??
            'Nenhuma aba contém cabeçalhos e participantes válidos.',
      );
    } on ExcelException catch (error) {
      throw FormatException(
        'Não foi possível abrir a planilha Excel: ${error.message}',
      );
    }
  }

  static String _cellText(CellValue? value) {
    if (value == null) return '';
    if (value is TextCellValue) return value.text;
    return value.toString();
  }
}
