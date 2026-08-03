import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';

class CertGenerator {
  /// Gera a imagem PNG do certificado.
  ///
  /// [textPositionX] e [textPositionY] são valores normalizados (0.0 a 1.0)
  /// que indicam onde o centro do texto será posicionado na imagem.
  /// 0.5 / 0.5 = centro exato da imagem.
  static Future<Uint8List> generateCertificateImage(
    ui.Image templateImage,
    Map<String, dynamic> rowData,
    String textTemplate,
    double fontSize,
    String fontFamily,
    Color fontColor, {
    double textPositionX = 0.5,
    double textPositionY = 0.5,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final size = Size(templateImage.width.toDouble(), templateImage.height.toDouble());
    canvas.drawImage(templateImage, Offset.zero, Paint());

    // Substituir variáveis
    String parsedText = textTemplate;
    rowData.forEach((key, value) {
      parsedText = parsedText.replaceAll('{$key}', value.toString());
    });

    final textSpan = TextSpan(
      text: parsedText,
      style: TextStyle(
        color: fontColor,
        fontSize: fontSize,
        fontFamily: fontFamily,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout(
      minWidth: 0,
      maxWidth: size.width * 0.8,
    );

    // Calcular posição a partir das coordenadas normalizadas
    // O ponto de ancoragem é o CENTRO do bloco de texto
    final anchorX = size.width * textPositionX;
    final anchorY = size.height * textPositionY;

    final offset = Offset(
      anchorX - textPainter.width / 2,
      anchorY - textPainter.height / 2,
    );

    textPainter.paint(canvas, offset);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }
}
