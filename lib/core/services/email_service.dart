import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Resultado de um envio: [error] é nulo quando o e-mail foi aceito.
class EmailSendResult {
  final String? error;

  /// Verdadeiro quando o servidor recusou o código de acesso (não adianta
  /// continuar o lote).
  final bool unauthorized;

  const EmailSendResult({this.error, this.unauthorized = false});

  bool get success => error == null;
}

class EmailService {
  static Future<EmailSendResult> sendEmailWithAttachment({
    required String accessCode,
    required String replyTo,
    required String toEmail,
    required String subject,
    required String textBody,
    required String attachmentName,
    required Uint8List attachmentBytes,
  }) async {
    final response = await http.post(
      Uri.parse('/api/email'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessCode',
      },
      body: jsonEncode({
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
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return const EmailSendResult();
    }

    String message = 'Erro ${response.statusCode}';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is String) message = decoded['error'];
    } catch (_) {}
    debugPrint('Failed to send email to $toEmail: ${response.statusCode} - $message');
    return EmailSendResult(
      error: message,
      unauthorized: response.statusCode == 401 || response.statusCode == 503,
    );
  }
}
