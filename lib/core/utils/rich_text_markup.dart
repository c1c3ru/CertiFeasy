import 'package:flutter/painting.dart';

/// Marcação leve usada no texto do certificado.
///
/// O texto é guardado como string simples e interpretado só por este parser:
/// não há HTML, links nem nada executável, então o que vem do CSV não consegue
/// injetar conteúdo — no máximo vira texto literal (ver [escapeMarkup]).
///
/// Formatação em linha:
///   **negrito**   *itálico*   __sublinhado__   ~~tachado~~
/// Início de linha:
///   # Título      ## Subtítulo      - item de lista
///   [esquerda] …  [centro] …  [direita] …  [justificado] …
/// Use `\` antes de um caractere especial para escrevê-lo literalmente.

/// Tamanho máximo do texto do certificado (frente ou verso).
const int kMaxTemplateLength = 5000;

const _specialChars = r'\*_~[]#|-';

enum MarkupAlign { left, center, right, justify }

const Map<MarkupAlign, String> kAlignTags = {
  MarkupAlign.left: '[esquerda]',
  MarkupAlign.center: '[centro]',
  MarkupAlign.right: '[direita]',
  MarkupAlign.justify: '[justificado]',
};

class MarkupRun {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;

  const MarkupRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
  });

  @override
  bool operator ==(Object other) =>
      other is MarkupRun &&
      other.text == text &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.strike == strike;

  @override
  int get hashCode => Object.hash(text, bold, italic, underline, strike);

  @override
  String toString() =>
      'MarkupRun("$text"${bold ? ' b' : ''}${italic ? ' i' : ''}${underline ? ' u' : ''}${strike ? ' s' : ''})';
}

class MarkupParagraph {
  final List<MarkupRun> runs;
  final MarkupAlign align;

  /// 0 = parágrafo normal, 1 = título, 2 = subtítulo.
  final int heading;

  const MarkupParagraph(this.runs, {this.align = MarkupAlign.center, this.heading = 0});

  String get plainText => runs.map((r) => r.text).join();

  TextAlign get textAlign => switch (align) {
        MarkupAlign.left => TextAlign.left,
        MarkupAlign.center => TextAlign.center,
        MarkupAlign.right => TextAlign.right,
        MarkupAlign.justify => TextAlign.justify,
      };

  /// Monta o [TextSpan] desta linha a partir do estilo base do certificado.
  TextSpan toSpan(TextStyle base) {
    final scale = switch (heading) { 1 => 1.6, 2 => 1.25, _ => 1.0 };
    final paragraphStyle = base.copyWith(
      fontSize: (base.fontSize ?? 14) * scale,
      fontWeight: heading > 0 ? FontWeight.bold : base.fontWeight,
    );
    // Linha vazia: um espaço de largura zero mantém a altura da linha.
    if (runs.isEmpty) return TextSpan(text: '\u200B', style: paragraphStyle);
    return TextSpan(
      style: paragraphStyle,
      children: runs.map((r) {
        final decorations = <TextDecoration>[
          if (r.underline) TextDecoration.underline,
          if (r.strike) TextDecoration.lineThrough,
        ];
        return TextSpan(
          text: r.text,
          style: TextStyle(
            fontWeight: r.bold ? FontWeight.bold : null,
            fontStyle: r.italic ? FontStyle.italic : null,
            decoration: decorations.isEmpty ? null : TextDecoration.combine(decorations),
            decorationColor: base.color,
          ),
        );
      }).toList(),
    );
  }
}

/// Escapa os caracteres de marcação para que o valor apareça literalmente.
/// Também remove caracteres de controle (exceto quebra de linha e tab).
String escapeMarkup(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final ch = String.fromCharCode(rune);
    if (rune < 0x20 && ch != '\n' && ch != '\t') continue;
    if (rune == 0x7F) continue;
    if (_specialChars.contains(ch)) buffer.write('\\');
    buffer.write(ch);
  }
  return buffer.toString();
}

final _variableRegex = RegExp(r'\{([^{}\n]+)\}');

/// Substitui `{coluna}` pelos valores da linha do CSV, já escapados.
///
/// A troca é feita numa única passada, então um valor que contenha `{outra}`
/// não é substituído de novo. Variáveis sem coluna correspondente ficam como estão.
String fillTemplate(String template, Map<String, dynamic> row) {
  return template.replaceAllMapped(_variableRegex, (m) {
    final key = m.group(1)!;
    if (!row.containsKey(key)) return m.group(0)!;
    return escapeMarkup(row[key]?.toString() ?? '');
  });
}

/// Remove a marcação e devolve só o texto visível.
String stripMarkup(String text) =>
    text.split('\n').map((l) => parseLine(l).plainText).join('\n');

final _alignTagRegex = RegExp(r'^\s*\[(esquerda|centro|direita|justificado)\]\s?');

/// Interpreta uma linha (sem `\n`) em um parágrafo formatado.
MarkupParagraph parseLine(String line) {
  var rest = line;
  var align = MarkupAlign.center;

  final alignMatch = _alignTagRegex.firstMatch(rest);
  if (alignMatch != null) {
    align = switch (alignMatch.group(1)) {
      'esquerda' => MarkupAlign.left,
      'direita' => MarkupAlign.right,
      'justificado' => MarkupAlign.justify,
      _ => MarkupAlign.center,
    };
    rest = rest.substring(alignMatch.end);
  }

  var heading = 0;
  var prefix = '';
  if (rest.startsWith('## ')) {
    heading = 2;
    rest = rest.substring(3);
  } else if (rest.startsWith('# ')) {
    heading = 1;
    rest = rest.substring(2);
  } else if (rest.startsWith('- ')) {
    prefix = '• ';
    rest = rest.substring(2);
  }

  final runs = parseInline(rest);
  if (prefix.isNotEmpty) runs.insert(0, MarkupRun(prefix));
  return MarkupParagraph(runs, align: align, heading: heading);
}

const _markers = ['**', '__', '~~', '*'];

/// Trecho do texto em linha: literal ou marcador, com a posição no texto
/// original. [paired] indica marcador com par (que de fato formata).
class InlineToken {
  final String text;
  final bool isMarker;
  final int start;
  final int end;
  bool paired = false;

  InlineToken(this.text, {required this.isMarker, required this.start, required this.end});
}

/// Separa o texto em literais e marcadores, respeitando escapes, e marca os
/// marcadores que têm par. Marcadores sem par são tratados como texto.
List<InlineToken> tokenizeInline(String text) {
  final tokens = <InlineToken>[];
  final literal = StringBuffer();
  var literalStart = 0;
  void flush(int end) {
    if (literal.isNotEmpty) {
      tokens.add(InlineToken(literal.toString(), isMarker: false, start: literalStart, end: end));
      literal.clear();
    }
  }

  var i = 0;
  while (i < text.length) {
    if (literal.isEmpty) literalStart = i;
    final ch = text[i];
    if (ch == '\\' && i + 1 < text.length) {
      literal.write(text[i + 1]);
      i += 2;
      continue;
    }
    final marker = _markers.firstWhere((m) => text.startsWith(m, i), orElse: () => '');
    if (marker.isNotEmpty) {
      flush(i);
      tokens.add(InlineToken(marker, isMarker: true, start: i, end: i + marker.length));
      i += marker.length;
      continue;
    }
    literal.write(ch);
    i++;
  }
  flush(text.length);

  final open = <String, int>{};
  for (var t = 0; t < tokens.length; t++) {
    final tok = tokens[t];
    if (!tok.isMarker) continue;
    final start = open.remove(tok.text);
    if (start != null) {
      tokens[start].paired = true;
      tok.paired = true;
    } else {
      open[tok.text] = t;
    }
  }
  return tokens;
}

/// Interpreta a formatação em linha. Marcadores sem par viram texto literal.
List<MarkupRun> parseInline(String text) {
  final runs = <MarkupRun>[];
  final active = <String>{};
  for (final tok in tokenizeInline(text)) {
    if (tok.isMarker && tok.paired) {
      if (!active.remove(tok.text)) active.add(tok.text);
      continue;
    }
    final run = MarkupRun(
      tok.text,
      bold: active.contains('**'),
      italic: active.contains('*'),
      underline: active.contains('__'),
      strike: active.contains('~~'),
    );
    // Junta com o trecho anterior quando o estilo é o mesmo.
    if (runs.isNotEmpty && _sameStyle(runs.last, run)) {
      final last = runs.removeLast();
      runs.add(MarkupRun(last.text + run.text,
          bold: run.bold, italic: run.italic, underline: run.underline, strike: run.strike));
    } else {
      runs.add(run);
    }
  }
  return runs;
}

/// Marcadores ativos na posição [offset] do texto em linha.
Set<String> activeMarkersAt(String text, int offset) {
  final active = <String>{};
  for (final tok in tokenizeInline(text)) {
    if (tok.start >= offset) break;
    if (tok.isMarker && tok.paired && tok.end <= offset) {
      if (!active.remove(tok.text)) active.add(tok.text);
    }
  }
  return active;
}

bool _sameStyle(MarkupRun a, MarkupRun b) =>
    a.bold == b.bold && a.italic == b.italic && a.underline == b.underline && a.strike == b.strike;

/// Divide uma linha de tabela `| a | b |` em células, respeitando `\|`.
List<String> splitTableRow(String inner) {
  final cells = <String>[];
  final cell = StringBuffer();
  for (var i = 0; i < inner.length; i++) {
    final ch = inner[i];
    if (ch == '\\' && i + 1 < inner.length) {
      cell
        ..write(ch)
        ..write(inner[i + 1]);
      i++;
    } else if (ch == '|') {
      cells.add(cell.toString().trim());
      cell.clear();
    } else {
      cell.write(ch);
    }
  }
  cells.add(cell.toString().trim());
  return cells;
}

/// Indica se a linha é de tabela: começa e termina com `|` não escapado.
bool isTableLine(String line) {
  final t = line.trim();
  if (t.length < 2 || !t.startsWith('|') || !t.endsWith('|')) return false;
  // Um `|` final escapado (\|) não fecha a tabela.
  var backslashes = 0;
  for (var i = t.length - 2; i >= 0 && t[i] == '\\'; i--) {
    backslashes++;
  }
  return backslashes.isEven;
}
