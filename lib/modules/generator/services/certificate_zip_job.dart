import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/cert_generator.dart';
import '../../../core/utils/certificate_file_names.dart';

// ─── Geração do ZIP ──────────────────────────────────────────────────────────
void generateZipWorker(Map<String, dynamic> args) async {
  final SendPort sendPort = args['sendPort'];
  await generateZipJob(args, sendPort.send);
}

/// Gera o ZIP e reporta pelo [send]: progresso (double), o ZIP (Uint8List)
/// ou 'ERROR:...' (String).
Future<void> generateZipJob(Map<String, dynamic> args, void Function(Object message) send) async {
  try {
    final List<Map<String, dynamic>> data = args['data'];
    final List<String> headers = List<String>.from(args['headers'] ?? []);
    final Uint8List imgBytes = args['imgBytes'];
    final String textTemplate = args['textTemplate'];
    final double fontSize = args['fontSize'];
    final String fontFamily = args['fontFamily'];
    final int fontColor = args['fontColor'];
    final double textPositionX = args['textPositionX'] ?? 0.5;
    final double textPositionY = args['textPositionY'] ?? 0.5;

    final Uint8List? backImgBytes = args['backImgBytes'];
    final String backTextTemplate = args['backTextTemplate'] ?? '';
    final double backFontSize = args['backFontSize'] ?? 32.0;
    final String backFontFamily = args['backFontFamily'] ?? 'Roboto';
    final int backFontColor = args['backFontColor'] ?? 0xFF000000;
    final double backTextPositionX = args['backTextPositionX'] ?? 0.5;
    final double backTextPositionY = args['backTextPositionY'] ?? 0.5;
    final String pdfModeStr = args['pdfMode'] ?? 'frontOnly';
    
    final bool generateFront = pdfModeStr != 'backOnly';
    final bool generateBack = pdfModeStr != 'frontOnly' && backImgBytes != null;

    ui.Image? templateImage;
    if (generateFront) {
      final codec = await ui.instantiateImageCodec(imgBytes);
      final frameInfo = await codec.getNextFrame();
      templateImage = frameInfo.image;
    }

    ui.Image? backTemplateImage;
    if (generateBack) {
      final codec = await ui.instantiateImageCodec(backImgBytes!);
      final frameInfo = await codec.getNextFrame();
      backTemplateImage = frameInfo.image;
    }

    final archive = Archive();
    final baseNames = CertificateFileNames.uniqueBaseNames(data, headers);

    for (int i = 0; i < data.length; i++) {
      final row = data[i];
      
      final cleanName = baseNames[i];

      if (generateFront && templateImage != null) {
        final certBytes = await CertGenerator.generateCertificateImage(
          templateImage,
          row,
          textTemplate,
          fontSize,
          fontFamily,
          Color(fontColor),
          textPositionX: textPositionX,
          textPositionY: textPositionY,
        );
        final fileName = generateBack ? '${cleanName}_frente.png' : '$cleanName.png';
        archive.addFile(ArchiveFile(fileName, certBytes.length, certBytes));
      }

      if (generateBack && backTemplateImage != null) {
        final backBytes = await CertGenerator.generateCertificateImage(
          backTemplateImage,
          row,
          backTextTemplate,
          backFontSize,
          backFontFamily,
          Color(backFontColor),
          textPositionX: backTextPositionX,
          textPositionY: backTextPositionY,
        );
        final fileName = generateFront ? '${cleanName}_verso.png' : '$cleanName.png';
        archive.addFile(ArchiveFile(fileName, backBytes.length, backBytes));
      }

      send((i + 1) / data.length);
    }

    final zipData = ZipEncoder().encode(archive);
    send(Uint8List.fromList(zipData));
  } catch (e) {
    send('ERROR:$e');
  }
}
