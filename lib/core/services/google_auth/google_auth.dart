/// Login com Google para liberar o envio de e-mails (só na versão web).
///
/// Fora da web, [initGoogleAuth] devolve falso e o app continua usando o
/// código de acesso.
library;

export 'google_auth_stub.dart' if (dart.library.js_interop) 'google_auth_web.dart';
export 'google_session.dart';
