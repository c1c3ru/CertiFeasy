import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../modules/generator/blocs/generator_state.dart';
import 'cert_generator.dart';

/// Utilitário para geração de PDF em lote de certificados.
///
/// Pode ser chamado diretamente ou via [generatePdfInIsolate] para
/// manter o event loop do Flutter responsivo durante a geração.
class CertPdfGenerator {
  /// Gera o PDF completo e retorna os bytes prontos para salvar/compartilhar.
  ///
  /// [data]           — lista de mapas com as variáveis de cada certificado
  /// [headers]        — cabeçalhos do CSV (para naming)
  /// [frontImgBytes]  — PNG do template da frente
  /// [backImgBytes]   — PNG do template do verso (null se mode == frontOnly)
  /// [textTemplate]   — string com variáveis {chave}
  /// [fontSize]       — tamanho da fonte do texto
  /// [fontFamily]     — família da fonte
  /// [fontColor]      — cor da fonte como int (ARGB)
  /// [textPositionX]  — posição X normalizada (0.0–1.0) do texto na frente
  /// [textPositionY]  — posição Y normalizada (0.0–1.0) do texto na frente
  /// [mode]           — modo de saída (frontOnly / backOnly / frontAndBack)
  /// [sendPort]       — porta para reportar progresso (double 0.0–1.0)
  static Future<Uint8List> generateBatchPdf({
    required List<Map<String, dynamic>> data,
    required List<String> headers,
    required Uint8List frontImgBytes,
    Uint8List? backImgBytes,
    required String textTemplate,
    required double fontSize,
    required String fontFamily,
    required int fontColor,
    required double textPositionX,
    required double textPositionY,
    required PdfMode mode,
    required SendPort sendPort,
  }) async {
    // ── Decodificar imagens de template ─────────────────────────────────────
    final ui.Image frontTemplate = await _decodeImage(frontImgBytes);
    ui.Image? backTemplate;
    if (backImgBytes != null) {
      backTemplate = await _decodeImage(backImgBytes);
    }

    // ── Gerar PNG de cada certificado (frente) ──────────────────────────────
    final List<Uint8List> frontPngs = [];
    if (mode != PdfMode.backOnly) {
      for (int i = 0; i < data.length; i++) {
        final png = await CertGenerator.generateCertificateImage(
          frontTemplate,
          data[i],
          textTemplate,
          fontSize,
          fontFamily,
          ui.Color(fontColor),
          textPositionX: textPositionX,
          textPositionY: textPositionY,
        );
        frontPngs.add(png);
        // Progresso: 0% → 50% para frentes (ou 0%→100% se frontOnly)
        final pct = mode == PdfMode.frontOnly
            ? (i + 1) / data.length
            : (i + 1) / data.length * 0.5;
        sendPort.send(pct);
      }
    }

    // ── Montar documento PDF ────────────────────────────────────────────────
    final pdf = pw.Document();

    // Páginas de FRENTE
    for (int i = 0; i < frontPngs.length; i++) {
      final img = pw.MemoryImage(frontPngs[i]);
      final imgSize = await _pdfImageSize(frontPngs[i]);
      pdf.addPage(pw.Page(
        pageFormat: imgSize,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context ctx) => pw.Image(img, fit: pw.BoxFit.fill),
      ));
    }

    // Páginas de VERSO
    if (mode != PdfMode.frontOnly && backTemplate != null && backImgBytes != null) {
      final backPng = backImgBytes; // verso é estático para todos
      final backImg = pw.MemoryImage(backPng);
      final backSize = await _pdfImageSize(backPng);

      for (int i = 0; i < data.length; i++) {
        pdf.addPage(pw.Page(
          pageFormat: backSize,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context ctx) => pw.Image(backImg, fit: pw.BoxFit.fill),
        ));
        // Progresso: 50%→100% para versos
        final pct = mode == PdfMode.backOnly
            ? (i + 1) / data.length
            : 0.5 + (i + 1) / data.length * 0.5;
        sendPort.send(pct);
      }
    }

    return await pdf.save();
  }

  // ─── Helpers privados ─────────────────────────────────────────────────────

  static Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Retorna o PdfPageFormat com as dimensões exatas da imagem (em pontos PDF).
  /// Usa 96 DPI como referência para converter pixels → pontos.
  static Future<PdfPageFormat> _pdfImageSize(Uint8List bytes) async {
    final img = await _decodeImage(bytes);
    const double dpi = 96.0;
    const double pointsPerInch = 72.0;
    final double pxToPoint = pointsPerInch / dpi;
    return PdfPageFormat(
      img.width * pxToPoint,
      img.height * pxToPoint,
    );
  }
}

// ─── Worker para Isolate ─────────────────────────────────────────────────────
/// Ponto de entrada do Isolate. Recebe os argumentos via [Map] e envia
/// o resultado (Uint8List do PDF) ou um erro prefixado com "ERROR:" de volta
/// pelo [SendPort].
void generatePdfWorker(Map<String, dynamic> args) async {
  final SendPort sendPort = args['sendPort'];
  try {
    final pdfBytes = await CertPdfGenerator.generateBatchPdf(
      data: List<Map<String, dynamic>>.from(args['data']),
      headers: List<String>.from(args['headers'] ?? []),
      frontImgBytes: args['frontImgBytes'],
      backImgBytes: args['backImgBytes'],
      textTemplate: args['textTemplate'],
      fontSize: args['fontSize'],
      fontFamily: args['fontFamily'],
      fontColor: args['fontColor'],
      textPositionX: args['textPositionX'] ?? 0.5,
      textPositionY: args['textPositionY'] ?? 0.5,
      mode: PdfMode.values.byName(args['pdfMode']),
      sendPort: sendPort,
    );
    sendPort.send(pdfBytes);
  } catch (e, st) {
    sendPort.send('ERROR:$e\n$st');
  }
}
