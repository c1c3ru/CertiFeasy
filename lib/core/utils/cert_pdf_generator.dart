import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../modules/generator/blocs/generator_state.dart';
import 'cert_generator.dart';
import 'image_compression.dart';

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
  /// [onProgress]     — callback de progresso (double 0.0–1.0)
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
    String backTextTemplate = '',
    double backFontSize = 32.0,
    String backFontFamily = 'Roboto',
    int backFontColor = 0xFF000000,
    double backTextPositionX = 0.5,
    double backTextPositionY = 0.5,
    required PdfMode mode,
    required void Function(double progress) onProgress,
  }) async {
    // ── Decodificar imagens de template ─────────────────────────────────────
    final ui.Image frontTemplate = await _decodeImage(frontImgBytes);
    ui.Image? backTemplate;
    if (backImgBytes != null) {
      backTemplate = await _decodeImage(backImgBytes);
    }

    final generateFront = mode != PdfMode.backOnly;
    final generateBack = mode != PdfMode.frontOnly && backTemplate != null;

    // ── Montar documento PDF ────────────────────────────────────────────────
    // Frente e verso de cada participante ficam em páginas seguidas
    // (F1, V1, F2, V2…), na ordem certa para impressão frente e verso.
    final pdf = pw.Document();
    Future<void> addPage(Uint8List png) async {
      final img = pw.MemoryImage(png);
      final size = await _pdfImageSize(png);
      pdf.addPage(pw.Page(
        pageFormat: size,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context ctx) => pw.Image(img, fit: pw.BoxFit.fill),
      ));
    }

    for (int i = 0; i < data.length; i++) {
      if (generateFront) {
        await addPage(await CertGenerator.generateCertificateImage(
          frontTemplate,
          data[i],
          textTemplate,
          fontSize,
          fontFamily,
          ui.Color(fontColor),
          textPositionX: textPositionX,
          textPositionY: textPositionY,
        ));
      }
      if (generateBack) {
        await addPage(await CertGenerator.generateCertificateImage(
          backTemplate,
          data[i],
          backTextTemplate,
          backFontSize,
          backFontFamily,
          ui.Color(backFontColor),
          textPositionX: backTextPositionX,
          textPositionY: backTextPositionY,
        ));
      }
      onProgress((i + 1) / data.length);
    }

    return await pdf.save();
  }

  /// [frontFormat]/[backFormat] fixam o tamanho da página quando a imagem foi
  /// reduzida para caber no e-mail (o tamanho impresso não muda).
  static Future<Uint8List> generateSinglePdf({
    required Uint8List frontImageBytes,
    Uint8List? backImageBytes,
    required PdfMode mode,
    PdfPageFormat? frontFormat,
    PdfPageFormat? backFormat,
  }) async {
    final pdf = pw.Document();

    final pageFormatFront = frontFormat ?? await _pdfImageSize(frontImageBytes);
    final memoryImageFront = pw.MemoryImage(frontImageBytes);

    if (mode != PdfMode.backOnly) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormatFront,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(memoryImageFront, fit: pw.BoxFit.cover),
            );
          },
        ),
      );
    }

    if (mode != PdfMode.frontOnly && backImageBytes != null) {
      final pageFormatBack = backFormat ?? await _pdfImageSize(backImageBytes);
      final memoryImageBack = pw.MemoryImage(backImageBytes);
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormatBack,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(memoryImageBack, fit: pw.BoxFit.cover),
            );
          },
        ),
      );
    }

    return await pdf.save();
  }

  /// Monta o PDF de um certificado com as páginas em JPEG, reduzindo a
  /// qualidade e depois a resolução até o arquivo caber em [maxBytes].
  /// O tamanho da página no PDF continua o da arte original.
  /// Se nem a última tentativa couber, devolve essa versão (a menor).
  static Future<Uint8List> generateSinglePdfWithinLimit({
    required ui.Image front,
    ui.Image? back,
    required PdfMode mode,
    required int maxBytes,
  }) async {
    final frontFormat = pageFormatForPixels(front.width, front.height);
    final backFormat = back == null ? null : pageFormatForPixels(back.width, back.height);

    late Uint8List pdfBytes;
    for (final (scale, quality) in _compressionSteps) {
      pdfBytes = await generateSinglePdf(
        frontImageBytes: await encodeJpeg(front, quality: quality, scale: scale),
        backImageBytes: back == null ? null : await encodeJpeg(back, quality: quality, scale: scale),
        mode: mode,
        frontFormat: frontFormat,
        backFormat: backFormat,
      );
      if (pdfBytes.length <= maxBytes) break;
    }
    return pdfBytes;
  }

  /// Tentativas de compressão: (escala da imagem, qualidade JPEG).
  static const _compressionSteps = [(1.0, 85), (1.0, 70), (0.75, 70), (0.5, 70)];

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
    return pageFormatForPixels(img.width, img.height);
  }

  /// Tamanho de página (em pontos PDF) de uma imagem de [width]×[height] px a 96 DPI.
  static PdfPageFormat pageFormatForPixels(int width, int height) {
    const double dpi = 96.0;
    const double pointsPerInch = 72.0;
    const double pxToPoint = pointsPerInch / dpi;
    return PdfPageFormat(width * pxToPoint, height * pxToPoint);
  }
}

// ─── Worker para Isolate ─────────────────────────────────────────────────────
/// Ponto de entrada do Isolate. Recebe os argumentos via [Map] e envia
/// o resultado (Uint8List do PDF) ou um erro prefixado com "ERROR:" de volta
/// pelo [SendPort].
/// Gera o PDF em lote e reporta pelo [send]: progresso (double), o PDF
/// (Uint8List) ou 'ERROR:...' (String). Roda num Isolate no app nativo e
/// direto na thread principal na Web, onde Isolates não existem.
Future<void> generatePdfJob(Map<String, dynamic> args, void Function(Object message) send) async {
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
      backTextTemplate: args['backTextTemplate'] ?? '',
      backFontSize: args['backFontSize'] ?? 32.0,
      backFontFamily: args['backFontFamily'] ?? 'Roboto',
      backFontColor: args['backFontColor'] ?? 0xFF000000,
      backTextPositionX: args['backTextPositionX'] ?? 0.5,
      backTextPositionY: args['backTextPositionY'] ?? 0.5,
      mode: PdfMode.values.byName(args['pdfMode']),
      onProgress: send,
    );
    send(pdfBytes);
  } catch (e, st) {
    send('ERROR:$e\n$st');
  }
}

void generatePdfWorker(Map<String, dynamic> args) async {
  final SendPort sendPort = args['sendPort'];
  await generatePdfJob(args, sendPort.send);
}
