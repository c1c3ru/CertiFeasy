import 'package:shared_preferences/shared_preferences.dart';

/// Limpa preferências antigas com dados de e-mail.
///
/// O CertiFeasy não persiste mais informações de envio no navegador.
/// Versões anteriores salvavam inclusive o código de acesso em texto simples;
/// esse legado é apagado na inicialização e nunca é restaurado.
class PreferencesService {
  PreferencesService._();

  static const _legacyEmailKeys = [
    'sender_email',
    'email_access_code',
    'email_subject',
    'email_body',
    'email_column',
  ];

  static Future<void> clearLegacyEmailConfig() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _legacyEmailKeys) {
      await prefs.remove(key);
    }
  }
}
