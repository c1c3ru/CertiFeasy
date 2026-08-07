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
  final String backTextTemplate;
  final double backFontSize;
  final String backFontFamily;
  final int backFontColorValue;
  final double progress;
  final bool isGenerating;

  /// Posição normalizada do texto (0.0 = esquerda/topo, 1.0 = direita/baixo)
  final double textPositionX;
  final double textPositionY;
  final double backTextPositionX;
  final double backTextPositionY;

  /// Índice da linha do CSV exibida na prévia
  final int selectedCsvRowIndex;

  // ── PDF ──────────────────────────────────────────────────────────────────
  /// Modo de saída PDF selecionado pelo usuário
  final PdfMode pdfMode;

  /// Imagem do verso do certificado (usada nos modos backOnly e frontAndBack)
  final Uint8List? backTemplateImageBytes;

  // ── Email ──────────────────────────────────────────────────────────────────
  final String resendApiKey;
  final String senderEmail;
  final String emailSubject;
  final String emailBody;
  final String emailColumn;
  final bool isSendingEmails;
  final int emailsSentCount;
  final int emailsTotalCount;

  GeneratorLoaded({
    required this.csvData,
    required this.csvHeaders,
    required this.mappedData,
    this.templateImageBytes,
    this.textTemplate = 'Certificamos que {nome} participou por {horas} horas.',
    this.fontSize = 48.0,
    this.fontFamily = 'Roboto',
    this.fontColorValue = 0xFF000000,
    this.backTextTemplate = 'Informações adicionais do verso...',
    this.backFontSize = 32.0,
    this.backFontFamily = 'Roboto',
    this.backFontColorValue = 0xFF000000,
    this.progress = 0.0,
    this.isGenerating = false,
    this.textPositionX = 0.5,
    this.textPositionY = 0.5,
    this.backTextPositionX = 0.5,
    this.backTextPositionY = 0.5,
    this.selectedCsvRowIndex = 0,
    this.pdfMode = PdfMode.frontOnly,
    this.backTemplateImageBytes,
    this.resendApiKey = '',
    this.senderEmail = 'cti.maracanau@ifce.edu.br',
    this.emailSubject = 'Seu Certificado',
    this.emailBody = 'Olá,\n\nSegue em anexo o seu certificado.\n\nAtenciosamente,\nEquipe',
    this.emailColumn = 'email',
    this.isSendingEmails = false,
    this.emailsSentCount = 0,
    this.emailsTotalCount = 0,
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
    String? backTextTemplate,
    double? backFontSize,
    String? backFontFamily,
    int? backFontColorValue,
    double? progress,
    bool? isGenerating,
    double? textPositionX,
    double? textPositionY,
    double? backTextPositionX,
    double? backTextPositionY,
    int? selectedCsvRowIndex,
    PdfMode? pdfMode,
    Uint8List? backTemplateImageBytes,
    bool clearBackTemplate = false,
    String? resendApiKey,
    String? senderEmail,
    String? emailSubject,
    String? emailBody,
    String? emailColumn,
    bool? isSendingEmails,
    int? emailsSentCount,
    int? emailsTotalCount,
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
      backTextTemplate: backTextTemplate ?? this.backTextTemplate,
      backFontSize: backFontSize ?? this.backFontSize,
      backFontFamily: backFontFamily ?? this.backFontFamily,
      backFontColorValue: backFontColorValue ?? this.backFontColorValue,
      progress: progress ?? this.progress,
      isGenerating: isGenerating ?? this.isGenerating,
      textPositionX: textPositionX ?? this.textPositionX,
      textPositionY: textPositionY ?? this.textPositionY,
      backTextPositionX: backTextPositionX ?? this.backTextPositionX,
      backTextPositionY: backTextPositionY ?? this.backTextPositionY,
      selectedCsvRowIndex: selectedCsvRowIndex ?? this.selectedCsvRowIndex,
      pdfMode: pdfMode ?? this.pdfMode,
      backTemplateImageBytes: clearBackTemplate ? null : (backTemplateImageBytes ?? this.backTemplateImageBytes),
      resendApiKey: resendApiKey ?? this.resendApiKey,
      senderEmail: senderEmail ?? this.senderEmail,
      emailSubject: emailSubject ?? this.emailSubject,
      emailBody: emailBody ?? this.emailBody,
      emailColumn: emailColumn ?? this.emailColumn,
      isSendingEmails: isSendingEmails ?? this.isSendingEmails,
      emailsSentCount: emailsSentCount ?? this.emailsSentCount,
      emailsTotalCount: emailsTotalCount ?? this.emailsTotalCount,
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
  
  /// Verdadeiro quando os requisitos para envio de e-mails estão satisfeitos
  bool get canSendEmails => canGeneratePdf && senderEmail.isNotEmpty && emailColumn.isNotEmpty;
}

class GeneratorError extends GeneratorState {
  final String message;
  GeneratorError(this.message);
}

class GeneratorSuccess extends GeneratorState {
  final String message;
  GeneratorSuccess(this.message);
}
