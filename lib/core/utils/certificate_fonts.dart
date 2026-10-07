import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fontes do Google Fonts oferecidas para o texto do certificado.
const kCertificateFonts = [
  'Roboto',
  'Lato',
  'Montserrat',
  'Open Sans',
  'Playfair Display',
  'Merriweather',
  'Dancing Script',
  'Pacifico',
  'Oswald',
  'Raleway',
];

/// Avisa quando alguma fonte termina de carregar, para a prévia se redesenhar.
final certificateFontsLoaded = ValueNotifier<int>(0);

/// Nome registrado de cada variante já carregada: (fonte, negrito, itálico).
final _registered = <(String, bool, bool), String>{};

(String, bool, bool) _variant(String family, FontWeight? weight, FontStyle? style) =>
    (family, (weight ?? FontWeight.normal).value >= FontWeight.w600.value, style == FontStyle.italic);

/// Aplica a fonte [family] a [style], na variante que corresponde ao peso e
/// ao estilo de [style] (negrito, itálico).
///
/// Só usa fontes já carregadas por [loadCertificateFonts]; enquanto isso, o
/// texto sai com a fonte padrão.
TextStyle applyCertificateFont(TextStyle style, String family) {
  final name = _registered[_variant(family, style.fontWeight, style.fontStyle)];
  if (name == null) return style.copyWith(fontFamily: family);
  return style.copyWith(fontFamily: name, fontFamilyFallback: [family]);
}

/// Baixa as variantes normal, negrito e itálico de [families] e espera o
/// carregamento terminar. Se falhar (ex.: sem internet), o texto continua
/// com a fonte padrão.
Future<void> loadCertificateFonts(Iterable<String> families) async {
  final requested = <(String, bool, bool), String>{};
  for (final family in families.where(kCertificateFonts.contains)) {
    for (final weight in const [FontWeight.normal, FontWeight.bold]) {
      for (final fontStyle in FontStyle.values) {
        final key = _variant(family, weight, fontStyle);
        if (_registered.containsKey(key)) continue;
        requested[key] =
            GoogleFonts.getFont(family, fontWeight: weight, fontStyle: fontStyle).fontFamily!;
      }
    }
  }
  if (requested.isEmpty) return;

  try {
    await GoogleFonts.pendingFonts();
  } catch (e) {
    debugPrint('Não foi possível carregar a fonte do certificado: $e');
    return;
  }
  _registered.addAll(requested);
  certificateFontsLoaded.value++;
}
