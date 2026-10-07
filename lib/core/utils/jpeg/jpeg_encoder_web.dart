import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'jpeg_encoder_io.dart' as fallback;

/// Codifica pixels RGBA em JPEG com o codificador nativo do navegador,
/// bem mais rápido que o codificador em Dart compilado para JavaScript.
Future<Uint8List> encodeRgbaAsJpeg(Uint8List rgba, int width, int height, int quality) async {
  final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
    ..width = width
    ..height = height;
  try {
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (context == null) return await fallback.encodeRgbaAsJpeg(rgba, width, height, quality);
    final clamped = Uint8ClampedList.view(rgba.buffer, rgba.offsetInBytes, rgba.lengthInBytes);
    context.putImageData(web.ImageData(clamped.toJS, width, height.toJS), 0, 0);

    final blob = Completer<web.Blob?>();
    canvas.toBlob((web.Blob? b) { blob.complete(b); }.toJS, 'image/jpeg', (quality / 100).toJS);
    final result = await blob.future;
    // Alguns navegadores recusam canvas muito grandes: usa o codificador em Dart.
    if (result == null) return await fallback.encodeRgbaAsJpeg(rgba, width, height, quality);
    final buffer = await result.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } finally {
    // Libera a memória do canvas logo, sem esperar o coletor de lixo.
    canvas
      ..width = 0
      ..height = 0;
  }
}
