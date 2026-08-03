import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _resendApiKey = 'resend_api_key';
  static const String _senderEmail = 'sender_email';
  static const String _emailSubject = 'email_subject';
  static const String _emailBody = 'email_body';
  static const String _emailColumn = 'email_column';

  static Future<void> saveResendConfig({
    required String apiKey,
    required String senderEmail,
    required String subject,
    required String body,
    required String emailColumn,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_resendApiKey, apiKey);
    await prefs.setString(_senderEmail, senderEmail);
    await prefs.setString(_emailSubject, subject);
    await prefs.setString(_emailBody, body);
    await prefs.setString(_emailColumn, emailColumn);
  }

  static Future<Map<String, String>> loadResendConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'apiKey': prefs.getString(_resendApiKey) ?? '',
      'senderEmail': prefs.getString(_senderEmail) ?? '',
      'subject': prefs.getString(_emailSubject) ?? 'Seu Certificado',
      'body': prefs.getString(_emailBody) ?? 'Olá,\n\nSegue em anexo o seu certificado.\n\nAtenciosamente,\nEquipe',
      'emailColumn': prefs.getString(_emailColumn) ?? 'email',
    };
  }
}
