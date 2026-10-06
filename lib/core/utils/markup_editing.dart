import 'package:flutter/services.dart';

import 'rich_text_markup.dart';

/// Operações da barra de formatação sobre o texto do certificado.
/// Cada função recebe o valor atual do campo e devolve o novo valor.

/// Aplica ou remove um marcador em linha (`**`, `*`, `__`, `~~`) na seleção.
TextEditingValue toggleInline(TextEditingValue value, String marker) {
  final text = value.text;
  final sel = _normalized(value.selection, text.length);
  final m = marker.length;

  if (sel.isCollapsed) {
    final newText = text.replaceRange(sel.start, sel.end, '$marker$marker');
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + m),
    );
  }

  final before = text.substring(0, sel.start);
  final selected = text.substring(sel.start, sel.end);
  final after = text.substring(sel.end);

  // Marcadores logo fora da seleção: remove.
  if (_endsWithMarker(before, marker) && _startsWithMarker(after, marker)) {
    final newText = before.substring(0, before.length - m) + selected + after.substring(m);
    return TextEditingValue(
      text: newText,
      selection: TextSelection(baseOffset: sel.start - m, extentOffset: sel.end - m),
    );
  }

  // Marcadores dentro da seleção: remove.
  if (selected.length >= 2 * m &&
      _startsWithMarker(selected, marker) &&
      _endsWithMarker(selected, marker)) {
    final inner = selected.substring(m, selected.length - m);
    return TextEditingValue(
      text: before + inner + after,
      selection: TextSelection(baseOffset: sel.start, extentOffset: sel.start + inner.length),
    );
  }

  return TextEditingValue(
    text: '$before$marker$selected$marker$after',
    selection: TextSelection(baseOffset: sel.start + m, extentOffset: sel.end + m),
  );
}

/// Define o alinhamento das linhas da seleção. Centralizado é o padrão (sem marcação).
TextEditingValue setAlignment(TextEditingValue value, MarkupAlign align) {
  return _mapSelectedLines(value, (line) {
    final parts = _LineParts.parse(line);
    return parts.copyWith(align: align).toString();
  });
}

/// Liga/desliga um prefixo de linha: `# `, `## ` ou `- `.
TextEditingValue toggleLinePrefix(TextEditingValue value, String prefix) {
  final lines = _selectedLines(value);
  final allHave = lines.every((l) => _LineParts.parse(l).prefix == prefix);
  return _mapSelectedLines(value, (line) {
    final parts = _LineParts.parse(line);
    return parts.copyWith(prefix: allHave ? '' : prefix).toString();
  });
}

/// Remove toda a formatação (em linha e de linha) das linhas selecionadas,
/// ou só do trecho selecionado quando a seleção está dentro de uma linha.
TextEditingValue clearFormatting(TextEditingValue value) {
  final text = value.text;
  final sel = _normalized(value.selection, text.length);
  final selected = text.substring(sel.start, sel.end);
  if (!sel.isCollapsed && !selected.contains('\n')) {
    final cleaned = _stripInlineMarkers(selected);
    return TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, cleaned),
      selection: TextSelection(baseOffset: sel.start, extentOffset: sel.start + cleaned.length),
    );
  }
  return _mapSelectedLines(value, (line) {
    final parts = _LineParts.parse(line);
    return _stripInlineMarkers(parts.content);
  });
}

/// Insere uma tabela Markdown vazia na posição do cursor, em linhas próprias.
TextEditingValue insertTable(TextEditingValue value, {int columns = 2, int rows = 2}) {
  final text = value.text;
  final sel = _normalized(value.selection, text.length);
  final header = '| ${List.generate(columns, (i) => 'Coluna ${i + 1}').join(' | ')} |';
  final separator = '|${List.filled(columns, '---').join('|')}|';
  final body = List.generate(rows, (_) => '| ${List.filled(columns, ' ').join(' | ')} |');
  var table = [header, separator, ...body].join('\n');

  final before = text.substring(0, sel.start);
  final after = text.substring(sel.end);
  if (before.isNotEmpty && !before.endsWith('\n')) table = '\n$table';
  if (after.isNotEmpty && !after.startsWith('\n')) table = '$table\n';

  return TextEditingValue(
    text: before + table + after,
    selection: TextSelection.collapsed(offset: before.length + table.length),
  );
}

/// Insere um texto (ex.: `{nome}`) no lugar da seleção.
TextEditingValue insertText(TextEditingValue value, String insert) {
  final text = value.text;
  final sel = _normalized(value.selection, text.length);
  return TextEditingValue(
    text: text.replaceRange(sel.start, sel.end, insert),
    selection: TextSelection.collapsed(offset: sel.start + insert.length),
  );
}

/// Estado de formatação no cursor, para destacar os botões ativos.
class FormattingState {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final MarkupAlign align;
  final String prefix;

  const FormattingState({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.align = MarkupAlign.center,
    this.prefix = '',
  });
}

FormattingState formattingAt(TextEditingValue value) {
  final text = value.text;
  final sel = _normalized(value.selection, text.length);
  final lineStart = sel.start == 0 ? 0 : text.lastIndexOf('\n', sel.start - 1) + 1;
  var lineEnd = text.indexOf('\n', sel.start);
  if (lineEnd < 0) lineEnd = text.length;
  final parts = _LineParts.parse(text.substring(lineStart, lineEnd));

  final contentStart = lineEnd - parts.content.length;
  final offset = (sel.start - contentStart).clamp(0, parts.content.length);
  final active = activeMarkersAt(parts.content, offset);
  return FormattingState(
    bold: active.contains('**'),
    italic: active.contains('*'),
    underline: active.contains('__'),
    strike: active.contains('~~'),
    align: parts.align,
    prefix: parts.prefix,
  );
}

// ─── Auxiliares ─────────────────────────────────────────────────────────────

TextSelection _normalized(TextSelection sel, int length) {
  if (!sel.isValid) return TextSelection.collapsed(offset: length);
  final start = sel.start.clamp(0, length);
  final end = sel.end.clamp(0, length);
  return TextSelection(baseOffset: start, extentOffset: end);
}

bool _endsWithMarker(String s, String marker) {
  if (!s.endsWith(marker)) return false;
  // `*` não deve casar com o fim de `**` (negrito), salvo `***`.
  if (marker == '*' && s.endsWith('**') && !s.endsWith('***')) return false;
  return true;
}

bool _startsWithMarker(String s, String marker) {
  if (!s.startsWith(marker)) return false;
  if (marker == '*' && s.startsWith('**') && !s.startsWith('***')) return false;
  return true;
}

String _stripInlineMarkers(String s) {
  final out = StringBuffer();
  var i = 0;
  while (i < s.length) {
    if (s[i] == '\\' && i + 1 < s.length) {
      out
        ..write(s[i])
        ..write(s[i + 1]);
      i += 2;
      continue;
    }
    final marker = ['**', '__', '~~', '*'].firstWhere((m) => s.startsWith(m, i), orElse: () => '');
    if (marker.isNotEmpty) {
      i += marker.length;
      continue;
    }
    out.write(s[i]);
    i++;
  }
  return out.toString();
}

(int, int) _lineRange(TextEditingValue value) {
  final text = value.text;
  final sel = _normalized(value.selection, text.length);
  final start = sel.start == 0 ? 0 : text.lastIndexOf('\n', sel.start - 1) + 1;
  var end = text.indexOf('\n', sel.end);
  if (end < 0) end = text.length;
  return (start, end);
}

List<String> _selectedLines(TextEditingValue value) {
  final (start, end) = _lineRange(value);
  return value.text.substring(start, end).split('\n');
}

TextEditingValue _mapSelectedLines(TextEditingValue value, String Function(String line) f) {
  final (start, end) = _lineRange(value);
  final text = value.text;
  final lines = text.substring(start, end).split('\n');
  final mapped = lines.map((l) => isTableLine(l) ? l : f(l)).join('\n');
  final newText = text.replaceRange(start, end, mapped);
  // Mantém o cursor no fim do trecho alterado quando a seleção era só um ponto.
  final selection = value.selection.isCollapsed
      ? TextSelection.collapsed(offset: start + mapped.length)
      : TextSelection(baseOffset: start, extentOffset: start + mapped.length);
  return TextEditingValue(text: newText, selection: selection);
}

final _alignPrefix = RegExp(r'^\s*\[(esquerda|centro|direita|justificado)\]\s?');

class _LineParts {
  final MarkupAlign align;
  final String prefix;
  final String content;

  const _LineParts(this.align, this.prefix, this.content);

  factory _LineParts.parse(String line) {
    var rest = line;
    var align = MarkupAlign.center;
    final m = _alignPrefix.firstMatch(rest);
    if (m != null) {
      align = kAlignTags.entries.firstWhere((e) => e.value == '[${m.group(1)}]').key;
      rest = rest.substring(m.end);
    }
    var prefix = '';
    for (final p in const ['## ', '# ', '- ']) {
      if (rest.startsWith(p)) {
        prefix = p;
        rest = rest.substring(p.length);
        break;
      }
    }
    return _LineParts(align, prefix, rest);
  }

  _LineParts copyWith({MarkupAlign? align, String? prefix}) =>
      _LineParts(align ?? this.align, prefix ?? this.prefix, content);

  @override
  String toString() {
    final tag = align == MarkupAlign.center ? '' : '${kAlignTags[align]} ';
    return '$tag$prefix$content';
  }
}
