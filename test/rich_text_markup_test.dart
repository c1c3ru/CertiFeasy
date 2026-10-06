import 'dart:ui' as ui;

import 'package:certifeasy/core/utils/cert_generator.dart';
import 'package:certifeasy/core/utils/markup_editing.dart';
import 'package:certifeasy/core/utils/rich_text_markup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _v(String text, int start, [int? end]) =>
    TextEditingValue(text: text, selection: TextSelection(baseOffset: start, extentOffset: end ?? start));

void main() {
  group('parseInline', () {
    test('interpreta negrito, itálico, sublinhado e tachado', () {
      expect(parseInline('a **b** *c* __d__ ~~e~~'), const [
        MarkupRun('a '),
        MarkupRun('b', bold: true),
        MarkupRun(' '),
        MarkupRun('c', italic: true),
        MarkupRun(' '),
        MarkupRun('d', underline: true),
        MarkupRun(' '),
        MarkupRun('e', strike: true),
      ]);
    });

    test('combina estilos aninhados', () {
      expect(parseInline('**a *b***'), const [
        MarkupRun('a ', bold: true),
        MarkupRun('b', bold: true, italic: true),
      ]);
    });

    test('marcador sem par fica como texto', () {
      expect(parseInline('5 * 3 = 15'), const [MarkupRun('5 * 3 = 15')]);
      expect(parseInline('**aberto'), const [MarkupRun('**aberto')]);
    });

    test('caractere escapado é literal', () {
      expect(parseInline(r'\*\*não\*\*'), const [MarkupRun('**não**')]);
    });
  });

  group('parseLine', () {
    test('título, subtítulo e lista', () {
      expect(parseLine('# Título').heading, 1);
      expect(parseLine('## Sub').heading, 2);
      expect(parseLine('- item').plainText, '• item');
    });

    test('alinhamento', () {
      expect(parseLine('[esquerda] a').align, MarkupAlign.left);
      expect(parseLine('[direita] # a').align, MarkupAlign.right);
      expect(parseLine('[direita] # a').heading, 1);
      expect(parseLine('[justificado] a').align, MarkupAlign.justify);
      expect(parseLine('a').align, MarkupAlign.center);
    });
  });

  group('fillTemplate (segurança)', () {
    test('valores do CSV não injetam formatação', () {
      final out = fillTemplate('Nome: {nome}', {'nome': '**Ana** [direita] # x | y'});
      final p = parseLine(out);
      expect(p.plainText, 'Nome: **Ana** [direita] # x | y');
      expect(p.runs.every((r) => !r.bold), isTrue);
      expect(p.align, MarkupAlign.center);
      expect(isTableLine(fillTemplate('{v}', {'v': '| a |'})), isFalse);
    });

    test('valor no início da linha não vira título nem lista', () {
      expect(parseLine(fillTemplate('{v}', {'v': '# x'})).heading, 0);
      expect(parseLine(fillTemplate('{v}', {'v': '- x'})).plainText, '- x');
    });

    test('remove caracteres de controle', () {
      expect(fillTemplate('{v}', {'v': 'a\u0000b\u0007c'}), 'abc');
    });

    test('substituição em uma passada só', () {
      expect(fillTemplate('{a} {b}', {'a': '{b}', 'b': 'X'}), '{b} X');
      expect(fillTemplate('{desconhecida}', {'a': '1'}), '{desconhecida}');
    });
  });

  group('edição', () {
    test('negrito envolve e remove a seleção', () {
      final on = toggleInline(_v('ola mundo', 4, 9), '**');
      expect(on.text, 'ola **mundo**');
      expect(on.selection, const TextSelection(baseOffset: 6, extentOffset: 11));
      final off = toggleInline(on, '**');
      expect(off.text, 'ola mundo');
    });

    test('itálico não desfaz o negrito', () {
      final v = toggleInline(_v('**a**', 2, 3), '*');
      expect(v.text, '***a***');
      expect(parseInline(v.text), const [MarkupRun('a', bold: true, italic: true)]);
    });

    test('cursor sem seleção insere par de marcadores', () {
      final v = toggleInline(_v('ab', 1), '__');
      expect(v.text, 'a____b');
      expect(v.selection.baseOffset, 3);
    });

    test('alinhamento e prefixos por linha', () {
      var v = setAlignment(_v('a\nb', 0, 3), MarkupAlign.right);
      expect(v.text, '[direita] a\n[direita] b');
      v = setAlignment(v, MarkupAlign.center);
      expect(v.text, 'a\nb');
      v = toggleLinePrefix(_v('a', 0), '# ');
      expect(v.text, '# a');
      v = toggleLinePrefix(v, '- ');
      expect(v.text, '- a');
      v = toggleLinePrefix(v, '- ');
      expect(v.text, 'a');
    });

    test('limpar formatação', () {
      expect(clearFormatting(_v('[direita] # **a** *b*', 0)).text, 'a b');
      expect(clearFormatting(_v('x **a** y', 2, 7)).text, 'x a y');
    });

    test('inserir tabela em linhas próprias', () {
      final v = insertTable(_v('antes', 5));
      expect(v.text.split('\n').first, 'antes');
      expect(isTableLine(v.text.split('\n')[1]), isTrue);
    });

    test('estado da formatação no cursor', () {
      final f = formattingAt(_v('[esquerda] **ab** c', 13));
      expect(f.bold, isTrue);
      expect(f.align, MarkupAlign.left);
      expect(formattingAt(_v('**ab** c', 8)).bold, isFalse);
    });
  });

  test('desenha texto formatado e tabela sem erros', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    CertGenerator.drawCertificateContent(
      canvas,
      const Size(800, 600),
      '# Certificado\n[esquerda] **Ana** participou\n\n| A | B |\n|---|---|\n| *1* | 2 |\n[justificado] fim',
      24,
      'Roboto',
      Colors.black,
    );
    final image = await recorder.endRecording().toImage(800, 600);
    expect(image.width, 800);
  });
}
