/// Gera nomes de arquivo previsíveis e únicos para os registros de um CSV.
///
/// A unicidade considera diferenças apenas de caixa e colisões após a
/// sanitização (ex.: "Ana Silva" e "Ana/Silva").
class CertificateFileNames {
  const CertificateFileNames._();

  static List<String> uniqueBaseNames(
    List<Map<String, dynamic>> rows,
    List<String> headers,
  ) {
    final used = <String>{};
    final names = <String>[];
    // O arquivo leva o nome da pessoa: usa a coluna "nome" quando ela existe,
    // mesmo que não seja a primeira da planilha.
    final nameColumn = headers.contains('nome') ? 'nome' : (headers.isEmpty ? null : headers.first);

    for (var i = 0; i < rows.length; i++) {
      final rawName = nameColumn == null ? '' : rows[i][nameColumn]?.toString() ?? '';
      final safeName = _sanitize(rawName);
      final base = safeName.isEmpty ? 'certificado_${i + 1}' : safeName;
      var candidate = base;
      var suffix = 2;
      while (!used.add(candidate.toLowerCase())) {
        candidate = '${base}_${suffix++}';
      }
      names.add(candidate);
    }

    return names;
  }

  static String _sanitize(String value) {
    final clean = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-ZÀ-ÿ0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return clean.length > 80 ? clean.substring(0, 80) : clean;
  }
}
