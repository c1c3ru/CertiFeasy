import 'dart:typed_data';

// ─── Enum de modo de geração PDF ───────────────────────────────────────────
enum PdfMode {
  frontOnly,
  backOnly,
  frontAndBack,
}

abstract class GeneratorState {}

class GeneratorInitial extends GeneratorState {}

class GeneratorLoading extends GeneratorState {}

class GeneratorLoaded extends GeneratorState {
  final List<List<dynamic>> csvData;
  final List<String> csvHeaders;
  final List<Map<String, dynamic>> mappedData;
  final Uint8List? templateImageBytes;
  final String textTemplate;
  final double fontSize;
  final String fontFamily;
  final int fontColorValue;
  final double progress;
  final bool isGenerating;

  /// Posição normalizada do texto (0.0 = esquerda/topo, 1.0 = direita/baixo)
  final double textPositionX;
  final double textPositionY;

  /// Índice da linha do CSV exibida na prévia
  final int selectedCsvRowIndex;

  // ── PDF ──────────────────────────────────────────────────────────────────
  /// Modo de saída PDF selecionado pelo usuário
  final PdfMode pdfMode;

  /// Imagem do verso do certificado (usada nos modos backOnly e frontAndBack)
  final Uint8List? backTemplateImageBytes;

  GeneratorLoaded({
    required this.csvData,
    required this.csvHeaders,
    required this.mappedData,
    this.templateImageBytes,
    this.textTemplate = 'Certificamos que {nome} participou por {horas} horas.',
    this.fontSize = 48.0,
    this.fontFamily = 'Roboto',
    this.fontColorValue = 0xFF000000,
    this.progress = 0.0,
    this.isGenerating = false,
    this.textPositionX = 0.5,
    this.textPositionY = 0.5,
    this.selectedCsvRowIndex = 0,
    this.pdfMode = PdfMode.frontOnly,
    this.backTemplateImageBytes,
  });

  GeneratorLoaded copyWith({
    List<List<dynamic>>? csvData,
    List<String>? csvHeaders,
    List<Map<String, dynamic>>? mappedData,
    Uint8List? templateImageBytes,
    String? textTemplate,
    double? fontSize,
    String? fontFamily,
    int? fontColorValue,
    double? progress,
    bool? isGenerating,
    double? textPositionX,
    double? textPositionY,
    int? selectedCsvRowIndex,
    PdfMode? pdfMode,
    Uint8List? backTemplateImageBytes,
    bool clearBackTemplate = false,
  }) {
    return GeneratorLoaded(
      csvData: csvData ?? this.csvData,
      csvHeaders: csvHeaders ?? this.csvHeaders,
      mappedData: mappedData ?? this.mappedData,
      templateImageBytes: templateImageBytes ?? this.templateImageBytes,
      textTemplate: textTemplate ?? this.textTemplate,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      fontColorValue: fontColorValue ?? this.fontColorValue,
      progress: progress ?? this.progress,
      isGenerating: isGenerating ?? this.isGenerating,
      textPositionX: textPositionX ?? this.textPositionX,
      textPositionY: textPositionY ?? this.textPositionY,
      selectedCsvRowIndex: selectedCsvRowIndex ?? this.selectedCsvRowIndex,
      pdfMode: pdfMode ?? this.pdfMode,
      backTemplateImageBytes: clearBackTemplate ? null : (backTemplateImageBytes ?? this.backTemplateImageBytes),
    );
  }

  /// Verdadeiro quando os requisitos para gerar PDF estão satisfeitos
  bool get canGeneratePdf {
    if (mappedData.isEmpty || templateImageBytes == null) return false;
    if (pdfMode == PdfMode.backOnly && backTemplateImageBytes == null) return false;
    if (pdfMode == PdfMode.frontAndBack && backTemplateImageBytes == null) return false;
    return true;
  }

  /// Verdadeiro quando os requisitos para gerar ZIP estão satisfeitos
  bool get canGenerateZip => mappedData.isNotEmpty && templateImageBytes != null;
}

class GeneratorError extends GeneratorState {
  final String message;
  GeneratorError(this.message);
}
