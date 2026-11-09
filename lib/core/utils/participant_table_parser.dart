import 'package:csv/csv.dart';

/// Dados tabulares normalizados para as variáveis usadas pelo gerador.
class ParticipantTable {
  final List<List<dynamic>> csvData;
  final List<String> headers;
  final List<Map<String, dynamic>> mappedData;

  const ParticipantTable({
    required this.csvData,
    required this.headers,
    required this.mappedData,
  });
}

/// Aceita CSV (vírgula/ponto e vírgula) e TSV exportado ou copiado de planilhas.
///
/// Mantém os nomes internos das variáveis, mesmo quando a planilha usa
/// cabeçalhos em português com espaços, hífens e acentos.
class ParticipantTableParser {
  const ParticipantTableParser._();

  static const _aliases = <String, String>{
    'nome': 'nome',
    'nome_completo': 'nome',
    'nome_do_participante': 'nome',
    'evento': 'evento',
    'nome_do_evento': 'evento',
    'data': 'data',
    'data_do_evento': 'data',
    'horas': 'horas',
    'carga_horaria': 'horas',
    'email': 'email',
    'e_mail': 'email',
    'email_do_participante': 'email',
    'e_mail_do_participante': 'email',
    'orientador': 'orientador',
    'orientadora': 'orientador',
    'orientador_a': 'orientador',
    'nome_do_orientador': 'orientador',
    'nome_do_orientador_a': 'orientador',
    'nome_trabalho': 'nome_trabalho',
    'titulo_do_trabalho': 'nome_trabalho',
    'titulo_trabalho': 'nome_trabalho',
    'email_orientador': 'email_orientador',
    'e_mail_orientador': 'email_orientador',
    'email_do_orientador': 'email_orientador',
    'e_mail_do_orientador': 'email_orientador',
    'email_do_orientador_a': 'email_orientador',
    'e_mail_do_orientador_a': 'email_orientador',
  };

  static final _validEmail = RegExp(
    r'^[^\s@<>,;"]+@[^\s@<>,;"]+\.[^\s@<>,;"]+$',
  );
  static final _displayAddress = RegExp(r'^.*<([^<>]+)>\s*$');

  static ParticipantTable parse(String content) {
    final sanitized = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final firstLine = sanitized.split('\n').firstWhere(
      (line) => line.trim().isNotEmpty,
      orElse: () => '',
    );
    if (firstLine.isEmpty) {
      throw const FormatException('O arquivo de participantes está vazio.');
    }

    final delimiter = firstLine.contains('\t')
        ? '\t'
        : firstLine.contains(';')
            ? ';'
            : ',';

    final rows = const CsvToListConverter(eol: '\n').convert(
      sanitized,
      fieldDelimiter: delimiter,
    );
    return parseRows(rows);
  }

  /// Mesma validação para CSV/TSV e células de Excel, sem serializar CSV.
  static ParticipantTable parseRows(List<List<dynamic>> rows) {
    if (rows.length < 2) {
      throw const FormatException('O arquivo precisa conter cabeçalho e participantes.');
    }

    final headers = rows.first.map((value) {
      final original = value
          .toString()
          .replaceAll(RegExp(r'[\ufeff\u200b]'), '')
          .trim();
      return _aliases[_fold(original)] ?? original;
    }).toList();

    if (headers.any((header) => header.isEmpty)) {
      throw const FormatException('Há uma coluna sem nome no cabeçalho.');
    }
    final seen = <String>{};
    for (final header in headers) {
      if (!seen.add(header.toLowerCase())) {
        throw FormatException(
          'A coluna "$header" aparece mais de uma vez. Remova a duplicidade.',
        );
      }
    }

    // A carga horária continua obrigatória nos certificados tradicionais.
    // Apenas apresentações com orientador e título podem omitir essa coluna.
    final isAcademicPresentation =
        headers.contains('orientador') && headers.contains('nome_trabalho');
    const mandatory = ['nome', 'evento', 'data', 'email'];
    final requiredHeaders = [
      ...mandatory,
      if (!isAcademicPresentation) 'horas',
    ];
    final missing =
        requiredHeaders.where((header) => !headers.contains(header)).toList();
    if (missing.isNotEmpty) {
      throw FormatException(
        'O CSV precisa conter as colunas: ${missing.join(', ')}. '
        'A coluna horas só pode ser omitida em apresentações de trabalhos '
        'com orientador e título do trabalho.',
      );
    }

    // Na apresentação acadêmica, mantemos {horas} com valor vazio para
    // preservar a interface e os templates já existentes.
    if (!headers.contains('horas')) headers.add('horas');

    final mappedData = <Map<String, dynamic>>[];
    final normalizedRows = <List<dynamic>>[headers];
    for (final sourceRow in rows.skip(1)) {
      if (sourceRow.every((cell) => cell.toString().trim().isEmpty)) continue;
      final row = <String, dynamic>{
        for (var i = 0; i < headers.length; i++)
          headers[i]: i < sourceRow.length
              ? _emailValue(headers[i], sourceRow[i])
              : '',
      };
      mappedData.add(row);
      normalizedRows.add([for (final header in headers) row[header]]);
    }

    if (mappedData.isEmpty) {
      throw const FormatException('O arquivo não possui participantes.');
    }

    return ParticipantTable(
      csvData: normalizedRows,
      headers: headers,
      mappedData: mappedData,
    );
  }

  static dynamic _emailValue(String header, dynamic value) {
    if (header != 'email' && header != 'email_orientador') return value;
    final original = value.toString().trim();
    final match = _displayAddress.firstMatch(original);
    if (match != null) {
      final address = match.group(1)!.trim();
      if (_validEmail.hasMatch(address)) return address;
    }
    return original;
  }

  static String _fold(String original) {
    var value = original.toLowerCase().trim();
    const accents = <String, String>{
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'é': 'e', 'ê': 'e', 'è': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c',
    };
    for (final entry in accents.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }
    return value
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
