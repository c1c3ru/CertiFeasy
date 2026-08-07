import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class EmailService {
  static Future<bool> sendEmailWithAttachment({
    required String senderEmail,
    required String toEmail,
    required String subject,
    required String textBody,
    required String attachmentName,
    required Uint8List attachmentBytes,
  }) async {
    final url = kIsWeb ? Uri.parse('/api/email') : Uri.parse('/api/email');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'from': senderEmail,
        'to': [toEmail],
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
      return true;
    } else {
      debugPrint('Failed to send email to $toEmail: ${response.statusCode} - ${response.body}');
      return false;
    }
  }
}
