import 'dart:convert';

import 'package:certifeasy/core/services/google_auth/google_session.dart';
import 'package:flutter_test/flutter_test.dart';

String fakeIdToken(Map<String, dynamic> payload) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'RS256'})}.${part(payload)}.assinatura';
}

void main() {
  test('lê a validade do ID token do Google', () {
    final token = fakeIdToken({'email': 'a@b.com', 'exp': 1800000000});
    expect(idTokenExpiry(token), DateTime.fromMillisecondsSinceEpoch(1800000000 * 1000, isUtc: true));
    expect(GoogleSession(email: 'a@b.com', idToken: token).expiresAt, isNotNull);
  });

  test('token sem formato JWT ou sem exp devolve nulo', () {
    expect(idTokenExpiry('codigo-de-acesso'), isNull);
    expect(idTokenExpiry(fakeIdToken({'email': 'a@b.com'})), isNull);
    expect(idTokenExpiry('a.%%%.c'), isNull);
  });
}
