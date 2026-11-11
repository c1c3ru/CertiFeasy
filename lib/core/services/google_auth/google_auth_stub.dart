import 'package:flutter/widgets.dart';

import 'google_session.dart';

/// Fora da web não há login com Google: o envio usa o código de acesso.
Future<bool> initGoogleAuth(void Function(GoogleSession? session) onSessionChanged) async => false;

Widget googleSignInButton() => const SizedBox.shrink();

Future<void> googleSignOut() async {}

/// Fora da web não existe listener de autenticação.
void detachGoogleAuthListener() {}
