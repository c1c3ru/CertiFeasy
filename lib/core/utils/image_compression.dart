import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'jpeg/jpeg_encoder.dart';

/// Redimensiona [image] por [scale] sobre fundo branco e codifica em JPEG.
///
/// Usado nos anexos de e-mail: um certificado em JPEG costuma ficar várias
/// vezes menor que em PNG, com diferença visual imperceptível.
Future<Uint8List> encodeJpeg(ui.Image image, {int quality = 85, double scale = 1.0}) async {
  final width = (image.width * scale).round().clamp(1, image.width);
  final height = (image.height * scale).round().clamp(1, image.height);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final dst = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  // JPEG não tem transparência: áreas transparentes viram branco, não preto.
  canvas.drawRect(dst, Paint()..color = const Color(0xFFFFFFFF));
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    dst,
    Paint()..filterQuality = FilterQuality.high,
  );
  final flat = await recorder.endRecording().toImage(width, height);
  final rgba = await flat.toByteData(format: ui.ImageByteFormat.rawRgba);
  flat.dispose();

  final bytes = rgba!.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes);
  return encodeRgbaAsJpeg(bytes, width, height, quality);
}
