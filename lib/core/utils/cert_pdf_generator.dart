import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../modules/generator/blocs/generator_state.dart';
import 'cert_generator.dart';
import 'certificate_file_names.dart';
import 'image_compression.dart';

/// Utilitário para geração de PDF em lote de certificados.
///
/// Pode ser chamado diretamente ou via [generatePdfInIsolate] para
/// manter o event loop do Flutter responsivo durante a geração.
class CertPdfGenerator {
  /// Gera um PDF por participante, cada um com o nome da pessoa
  /// (ex.: `Ana_Silva.pdf`), com frente e/ou verso conforme [mode].
  ///
  /// Com um participante só, devolve o próprio PDF; com mais de um, devolve
  /// um ZIP com todos os PDFs (o navegador não baixa vários arquivos de uma
  /// vez sem pedir permissão para cada um).
  static Future<IndividualPdfsResult> generateIndividualPdfs({
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
    final frontTemplate = await _decodeImage(frontImgBytes);
    final backTemplate = backImgBytes == null ? null : await _decodeImage(backImgBytes);
    final generateFront = mode != PdfMode.backOnly;
    final generateBack = mode != PdfMode.frontOnly && backTemplate != null;
    final baseNames = CertificateFileNames.uniqueBaseNames(data, headers);

    final archive = Archive();
    Uint8List? singlePdf;
    for (int i = 0; i < data.length; i++) {
      final pdf = pw.Document();
      Future<void> addPage(Uint8List png) async {
        final size = await _pdfImageSize(png);
        pdf.addPage(pw.Page(
          pageFormat: size,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context ctx) => pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.fill),
        ));
      }

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

      final bytes = await pdf.save();
      if (data.length == 1) {
        singlePdf = bytes;
      } else {
        archive.addFile(ArchiveFile('${baseNames[i]}.pdf', bytes.length, bytes));
      }
      onProgress((i + 1) / data.length);
    }
    frontTemplate.dispose();
    backTemplate?.dispose();

    if (singlePdf != null) {
      return IndividualPdfsResult(bytes: singlePdf, fileName: '${baseNames.single}.pdf', isZip: false);
    }
    return IndividualPdfsResult(
      bytes: Uint8List.fromList(ZipEncoder().encode(archive)),
      fileName: 'certificados_pdf.zip',
      isZip: true,
    );
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

/// Resultado de [CertPdfGenerator.generateIndividualPdfs].
class IndividualPdfsResult {
  final Uint8List bytes;

  /// Nome sugerido para o download: o PDF da pessoa ou o ZIP com todos.
  final String fileName;
  final bool isZip;

  const IndividualPdfsResult({required this.bytes, required this.fileName, required this.isZip});
}

// ─── Worker para Isolate ─────────────────────────────────────────────────────
/// Gera um PDF por participante e reporta pelo [send]: progresso (double),
/// `FILENAME:nome-do-arquivo` (String), o PDF ou ZIP (Uint8List) ou 'ERROR:...'
/// (String). Roda num Isolate no app nativo e direto na thread principal na
/// Web, onde Isolates não existem.
Future<void> generatePdfJob(Map<String, dynamic> args, void Function(Object message) send) async {
  try {
    final result = await CertPdfGenerator.generateIndividualPdfs(
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
    // O nome do arquivo vai antes dos bytes, que encerram o job.
    send('FILENAME:${result.fileName}');
    send(result.bytes);
  } catch (e, st) {
    send('ERROR:$e\n$st');
  }
}

void generatePdfWorker(Map<String, dynamic> args) async {
  final SendPort sendPort = args['sendPort'];
  await generatePdfJob(args, sendPort.send);
}
