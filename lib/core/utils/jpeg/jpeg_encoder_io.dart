import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Codifica pixels RGBA em JPEG com o codificador em Dart.
Future<Uint8List> encodeRgbaAsJpeg(Uint8List rgba, int width, int height, int quality) async {
  final pixels = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(pixels, quality: quality);
}
