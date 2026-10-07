import 'package:certifeasy/core/utils/certificate_fonts.dart';
import 'package:certifeasy/core/utils/rich_text_markup.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fonte ainda não carregada fica com o nome da família', () {
    expect(applyCertificateFont(const TextStyle(), 'Pacifico').fontFamily, 'Pacifico');
    expect(applyCertificateFont(const TextStyle(), 'Arial').fontFamily, 'Arial');
  });

  test('negrito, itálico e título pedem a variante certa da fonte', () {
    TextStyle font(TextStyle s) => s.copyWith(
          fontFamily: 'F_${s.fontWeight == FontWeight.bold ? 'b' : 'n'}'
              '${s.fontStyle == FontStyle.italic ? 'i' : ''}',
        );
    final span = parseLine('a **b** *c*').toSpan(const TextStyle(fontSize: 20), font: font);
    expect(span.style!.fontFamily, 'F_n');
    final runs = span.children!.cast<TextSpan>();
    expect(runs.map((r) => r.text), ['a ', 'b', ' ', 'c']);
    expect(runs[0].style!.fontFamily, isNull); // herda a do parágrafo
    expect(runs[1].style!.fontFamily, 'F_b');
    expect(runs[3].style!.fontFamily, 'F_ni');

    final heading = parseLine('# t').toSpan(const TextStyle(fontSize: 20), font: font);
    expect(heading.style!.fontFamily, 'F_b');
  });
}
