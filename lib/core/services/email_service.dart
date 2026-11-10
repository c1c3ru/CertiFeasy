import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Por que um envio falhou, para dizer ao usuário o que fazer.
enum EmailFailureKind {
  /// Endereço do destinatário errado (erro de digitação na planilha).
  invalidAddress,

  /// Código de acesso/login recusado ou servidor sem configuração: os
  /// próximos envios também falhariam.
  unauthorized,

  /// Problema técnico (internet, Gmail, servidor): tentar de novo mais tarde.
  technical,

  /// O servidor recusou o conteúdo (assunto, mensagem ou anexo).
  rejectedContent,
}

/// Resultado de um envio: [error] é nulo quando o e-mail foi aceito.
class EmailSendResult {
  final String? error;
  final EmailFailureKind? kind;

  /// Verdadeiro quando o servidor recusou o código de acesso ou a conta do
  /// Google (não adianta continuar o lote).
  final bool unauthorized;

  const EmailSendResult({this.error, this.unauthorized = false});

  bool get success => error == null;

  /// Verdadeiro quando não adianta continuar o lote.
  bool get unauthorized => kind == EmailFailureKind.unauthorized;
}

class EmailService {
  /// Tempo máximo de espera por resposta do servidor em cada envio.
  static const timeout = Duration(seconds: 60);

  static Future<EmailSendResult> sendEmailWithAttachment({
    required String accessCode,
    required String replyTo,
    required String toEmail,
    required String subject,
    required String textBody,
    required String attachmentName,
    required Uint8List attachmentBytes,
    http.Client? client,
  }) async {
    final http.Response response;
    try {
      final body = jsonEncode({
        'to': toEmail,
        'replyTo': replyTo,
        'subject': subject,
        'text': textBody,
        'attachments': [
          {
            'filename': attachmentName,
            'content': base64Encode(attachmentBytes),
          }
        ],
      });
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessCode',
      };
      final uri = Uri.parse('/api/email');
      response = await (client != null
              ? client.post(uri, headers: headers, body: body)
              : http.post(uri, headers: headers, body: body))
          .timeout(timeout);
    } on TimeoutException {
      return const EmailSendResult(
        error: 'o servidor demorou demais para responder',
        kind: EmailFailureKind.technical,
      );
    } catch (e) {
      debugPrint('Failed to send email to $toEmail: $e');
      return const EmailSendResult(
        error: 'sem conexão com o servidor (confira a internet)',
        kind: EmailFailureKind.technical,
      );
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return const EmailSendResult();
    }

    String message = 'erro ${response.statusCode} no servidor';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is String) message = decoded['error'];
    } catch (_) {}
    debugPrint('Failed to send email to $toEmail: ${response.statusCode} - $message');
    return EmailSendResult(
      error: message,
      unauthorized: response.statusCode == 401 ||
          response.statusCode == 403 ||
          response.statusCode == 503,
    );
  }
}
