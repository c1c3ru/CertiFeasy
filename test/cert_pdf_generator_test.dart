import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:certifeasy/core/utils/cert_pdf_generator.dart';
import 'package:certifeasy/modules/generator/blocs/generator_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> _png(int w, int h) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = Colors.white);
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Larguras das páginas, na ordem em que aparecem no PDF.
List<String> _pageWidths(Uint8List pdf) {
  final text = latin1.decode(pdf);
  return RegExp(r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)').allMatches(text).map((m) => m.group(1)!).toList();
}

void main() {
  test('frente e verso de cada participante ficam em páginas seguidas', () async {
    final front = await _png(200, 100); // 150 pt de largura
    final back = await _png(120, 100); // 90 pt de largura
    final pdf = await CertPdfGenerator.generateBatchPdf(
      data: [
        {'nome': 'Ana'},
        {'nome': 'Bruno'},
      ],
      headers: const ['nome'],
      frontImgBytes: front,
      backImgBytes: back,
      textTemplate: 'Frente {nome}',
      fontSize: 12,
      fontFamily: 'Roboto',
      fontColor: 0xFF000000,
      textPositionX: 0.5,
      textPositionY: 0.5,
      backTextTemplate: 'Verso {nome}',
      mode: PdfMode.frontAndBack,
      onProgress: (_) {},
    );
    final widths = _pageWidths(pdf).map(double.parse).toList();
    expect(widths, [150, 90, 150, 90]);
  });
}
