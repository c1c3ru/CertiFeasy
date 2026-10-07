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
  test('PDF do e-mail fica abaixo do limite e mantém o tamanho da página', () async {
    final front = await _busyImage(2000, 1414, 1);
    final back = await _busyImage(2000, 1414, 2);
    final pngPdf = await CertPdfGenerator.generateSinglePdf(
      frontImageBytes: await _pngBytes(front),
      backImageBytes: await _pngBytes(back),
      mode: PdfMode.frontAndBack,
    );
    final limit = pngPdf.length ~/ 3;
    final pdf = await CertPdfGenerator.generateSinglePdfWithinLimit(
      front: front,
      back: back,
      mode: PdfMode.frontAndBack,
      maxBytes: limit,
    );
    expect(pdf.length, lessThanOrEqualTo(limit));
    expect(_pageWidths(pdf).map(double.parse).toList(), [1500, 1500]);
  });

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

Future<ui.Image> _busyImage(int w, int h, int seed) async {
  // Arte "difícil" de comprimir: degradê com linhas finas e ruído.
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(w.toDouble(), h.toDouble()),
          [const Color(0xFFE8F5E9), const Color(0xFF1B5E20)]),
  );
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  var r = seed;
  for (var i = 0; i < 4000; i++) {
    r = (r * 1103515245 + 12345) & 0x7fffffff;
    line.color = Color(0xFF000000 | (r & 0xFFFFFF));
    final x = (r % w).toDouble();
    final y = ((r >> 8) % h).toDouble();
    canvas.drawLine(Offset(x, y), Offset(x + 40, y + 25), line);
  }
  return recorder.endRecording().toImage(w, h);
}

Future<Uint8List> _pngBytes(ui.Image image) async =>
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

