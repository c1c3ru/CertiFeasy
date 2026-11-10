import 'dart:convert';
import 'dart:typed_data';

import 'package:certifeasy/core/services/email_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<EmailSendResult> send(http.Client client) => EmailService.sendEmailWithAttachment(
      accessCode: 'x',
      replyTo: 'a@b.com',
      toEmail: 'c@d.com',
      subject: 's',
      textBody: 't',
      attachmentName: 'a.pdf',
      attachmentBytes: Uint8List.fromList([1, 2, 3]),
      client: client,
    );

http.Client respond(int status, String error) =>
    MockClient((_) async => http.Response(jsonEncode({'error': error}), status));

void main() {
  test('sem internet vira problema técnico, sem derrubar o lote', () async {
    final result = await send(MockClient((_) async => throw http.ClientException('offline')));
    expect(result.success, isFalse);
    expect(result.kind, EmailFailureKind.technical);
    expect(result.error, contains('internet'));
  });

  test('classifica as respostas do servidor', () async {
    expect((await send(respond(200, ''))).success, isTrue);
    expect((await send(respond(400, 'Destinatário inválido.'))).kind, EmailFailureKind.invalidAddress);
    expect((await send(respond(400, 'Assunto inválido.'))).kind, EmailFailureKind.rejectedContent);
    expect((await send(respond(401, 'Código de acesso inválido.'))).unauthorized, isTrue);
    expect((await send(respond(403, 'Use uma conta @ifce.edu.br.'))).unauthorized, isTrue);
    expect((await send(respond(503, 'não configurado'))).unauthorized, isTrue);
    expect((await send(respond(502, 'Falha ao enviar o e-mail.'))).kind, EmailFailureKind.technical);
    expect((await send(respond(502, 'Falha ao enviar o e-mail.'))).error, 'Falha ao enviar o e-mail.');
  });
}
