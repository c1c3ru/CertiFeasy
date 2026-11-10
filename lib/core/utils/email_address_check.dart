/// Confere um endereço de e-mail da planilha antes do envio, para separar
/// erro de digitação de falha técnica.
library;

final _emailRegex = RegExp(r'^[^\s@<>,;"]+@[^\s@<>,;"]+\.[^\s@<>,;"]+$');

/// Provedores comuns: um domínio parecido com um destes (mas diferente) quase
/// sempre é erro de digitação, e o e-mail nunca chegaria.
const _commonDomains = [
  'gmail.com',
  'hotmail.com',
  'outlook.com',
  'live.com',
  'yahoo.com',
  'yahoo.com.br',
  'icloud.com',
  'bol.com.br',
  'uol.com.br',
];

/// Domínios reais parecidos com os de cima: nunca são tratados como erro.
const _otherKnownDomains = {
  'ymail.com', 'mail.com', 'email.com', 'msn.com', 'aol.com', 'gmx.com',
  'hotmail.com.br', 'outlook.com.br', 'live.com.br', 'terra.com.br', 'ig.com.br',
  'protonmail.com', 'proton.me',
};

/// Problema encontrado num endereço: [reason] explica em português e
/// [suggestion] traz o endereço provável, quando dá para adivinhar.
class EmailAddressIssue {
  final String reason;
  final String? suggestion;

  const EmailAddressIssue(this.reason, {this.suggestion});
}

/// Devolve nulo quando o endereço parece certo.
EmailAddressIssue? checkEmailAddress(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return const EmailAddressIssue('célula de e-mail vazia na planilha');
  if (RegExp(r'\s').hasMatch(value)) {
    return EmailAddressIssue('tem espaço no meio', suggestion: _validOrNull(value.replaceAll(RegExp(r'\s'), '')));
  }
  final at = '@'.allMatches(value).length;
  if (at == 0) return const EmailAddressIssue('falta o @');
  if (at > 1) return const EmailAddressIssue('tem mais de um @');
  if (!_emailRegex.hasMatch(value) || value.endsWith('.') || value.contains('..')) {
    return const EmailAddressIssue('formato inválido (confira o que vem depois do @)');
  }

  final local = value.substring(0, value.indexOf('@'));
  final domain = value.substring(value.indexOf('@') + 1).toLowerCase();
  if (_commonDomains.contains(domain) || _otherKnownDomains.contains(domain)) return null;

  // Ex.: "gmial.com", "hotmal.com", "gmail.con" no lugar do provedor certo.
  for (final known in _commonDomains) {
    final distance = _editDistance(domain, known);
    if (distance > 0 && distance <= 2) {
      return EmailAddressIssue('domínio "$domain" parece digitado errado', suggestion: '$local@$known');
    }
  }
  return null;
}

String? _validOrNull(String value) => checkEmailAddress(value) == null ? value : null;

int _editDistance(String a, String b) {
  if ((a.length - b.length).abs() > 2) return 3;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = [previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost].reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  return previous[b.length];
}
