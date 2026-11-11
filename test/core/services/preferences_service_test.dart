import 'package:certifeasy/core/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('apaga todas as preferências legadas, inclusive código de acesso',
      () async {
    SharedPreferences.setMockInitialValues({
      'sender_email': 'contato@ifce.edu.br',
      'email_access_code': 'segredo-antigo',
      'email_subject': 'Assunto antigo',
      'email_body': 'Mensagem antiga',
      'email_column': 'email_orientador',
      'outra_preferencia': 'preservada',
    });

    await PreferencesService.clearLegacyEmailConfig();

    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'sender_email',
      'email_access_code',
      'email_subject',
      'email_body',
      'email_column',
    ]) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
    expect(prefs.getString('outra_preferencia'), 'preservada');
  });
}
