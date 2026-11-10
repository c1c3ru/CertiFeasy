import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as gis;
import 'package:http/http.dart' as http;

import 'google_session.dart';

bool _initialized = false;

/// Busca o ID de cliente em /api/config e prepara o login com Google.
///
/// Devolve falso quando o servidor não tem o login com Google configurado
/// (GOOGLE_CLIENT_ID na Vercel); nesse caso o app mostra o campo de código de
/// acesso. A escolha de conta já mostra só contas do domínio liberado
/// (ifce.edu.br); quem confere de verdade é o servidor.
Future<bool> initGoogleAuth(void Function(GoogleSession? session) onSessionChanged) async {
  if (_initialized) return true;
  final String? clientId;
  String? allowedDomain;
  try {
    final response = await http.get(Uri.parse('/api/config'));
    if (response.statusCode != 200) return false;
    final decoded = jsonDecode(response.body);
    clientId = decoded is Map && decoded['googleClientId'] is String
        ? decoded['googleClientId'] as String
        : null;
    if (decoded is Map && decoded['allowedDomain'] is String) {
      allowedDomain = decoded['allowedDomain'] as String;
    }
  } catch (e) {
    debugPrint('google_auth: /api/config indisponível ($e)');
    return false;
  }
  if (clientId == null || clientId.isEmpty) return false;

  final signIn = GoogleSignIn.instance;
  await signIn.initialize(clientId: clientId, hostedDomain: allowedDomain);
  _initialized = true;

  signIn.authenticationEvents.listen(
    (event) {
      switch (event) {
        case GoogleSignInAuthenticationEventSignIn(:final user):
          final idToken = user.authentication.idToken;
          onSessionChanged(
            idToken == null ? null : GoogleSession(email: user.email, idToken: idToken),
          );
        case GoogleSignInAuthenticationEventSignOut():
          onSessionChanged(null);
      }
    },
    onError: (Object e) => debugPrint('google_auth: falha no login ($e)'),
  );

  // Quem já entrou antes volta conectado sem clicar (One Tap do Google).
  unawaited(signIn.attemptLightweightAuthentication());
  return true;
}

/// Botão oficial "Fazer login com o Google".
Widget googleSignInButton() => gis.renderButton(
      configuration: gis.GSIButtonConfiguration(
        theme: gis.GSIButtonTheme.filledBlue,
        text: gis.GSIButtonText.signinWith,
        shape: gis.GSIButtonShape.pill,
        locale: 'pt-BR',
      ),
    );

Future<void> googleSignOut() => GoogleSignIn.instance.signOut();
