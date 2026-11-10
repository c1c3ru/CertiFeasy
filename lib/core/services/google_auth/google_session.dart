import 'dart:convert';

/// Conta do Google conectada e o ID token que o /api/email confere.
class GoogleSession {
  final String email;
  final String idToken;

  const GoogleSession({required this.email, required this.idToken});

  /// Quando o ID token expira (o Google emite tokens válidos por ~1 hora).
  DateTime? get expiresAt => idTokenExpiry(idToken);
}

/// Lê o campo "exp" de um ID token (JWT) sem validar a assinatura; quem valida
/// é o servidor. Devolve nulo se o token não tiver esse formato.
DateTime? idTokenExpiry(String idToken) {
  final parts = idToken.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    final exp = payload is Map ? payload['exp'] : null;
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}
