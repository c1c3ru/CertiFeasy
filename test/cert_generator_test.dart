import 'dart:ui' as ui;

import 'package:certifeasy/core/utils/cert_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Desenha o texto numa arte vazia de [width] x [height] e devolve o
/// retângulo ocupado pelos pixels pintados.
Future<Rect> _textBounds(int width, int height) async {
  final recorder = ui.PictureRecorder();
  CertGenerator.drawCertificateContent(
    Canvas(recorder),
    Size(width.toDouble(), height.toDouble()),
    'Certificamos que Ana participou',
    48,
    'Roboto',
    Colors.black,
  );
  final image = await recorder.endRecording().toImage(width, height);
  final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();

  var left = width, top = height, right = -1, bottom = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (pixels.getUint8((y * width + x) * 4 + 3) == 0) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  return Rect.fromLTRB(left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0);
}

void main() {
  test('o texto ocupa a mesma proporção da arte em qualquer resolução', () async {
    final small = await _textBounds(1000, 700);
    final large = await _textBounds(3000, 2100);

    expect(small.width, greaterThan(0));
    expect(large.width / small.width, closeTo(3, 0.05));
    expect(large.height / small.height, closeTo(3, 0.05));
    expect(large.center.dx / 3, closeTo(small.center.dx, 2));
    expect(large.center.dy / 3, closeTo(small.center.dy, 2));
  });

  test('arte sem tamanho não desenha nada', () {
    final recorder = ui.PictureRecorder();
    CertGenerator.drawCertificateContent(
        Canvas(recorder), Size.zero, 'texto', 48, 'Roboto', Colors.black);
    recorder.endRecording().dispose();
  });
}
