import 'dart:typed_data';
import '../../../core/services/email_service.dart' show EmailFailureKind;

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
  /// E-mail para onde vão as respostas dos participantes (Reply-To).
  final String senderEmail;
  /// Código exigido pelo /api/email (variável EMAIL_API_TOKEN na Vercel).
  /// Só é usado quando o login com Google não está disponível.
  final String emailAccessCode;
  /// Verdadeiro quando o servidor tem o login com Google configurado.
  final bool googleSignInAvailable;
  /// Conta do Google conectada (vazio quando ninguém entrou).
  final String googleEmail;
  /// ID token do Google enviado ao /api/email no lugar do código de acesso.
  final String googleIdToken;
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
    this.senderEmail = 'cti.maracanau@ifce.edu.br',
    this.emailAccessCode = '',
    this.googleSignInAvailable = false,
    this.googleEmail = '',
    this.googleIdToken = '',
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
    String? senderEmail,
    String? emailAccessCode,
    bool? googleSignInAvailable,
    String? googleEmail,
    String? googleIdToken,
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
      senderEmail: senderEmail ?? this.senderEmail,
      emailAccessCode: emailAccessCode ?? this.emailAccessCode,
      googleSignInAvailable: googleSignInAvailable ?? this.googleSignInAvailable,
      googleEmail: googleEmail ?? this.googleEmail,
      googleIdToken: googleIdToken ?? this.googleIdToken,
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
  
  /// A coluna configurada precisa existir no CSV atual, sem fallback implícito.
  bool get hasValidEmailColumn => csvHeaders.contains(emailColumn);

  /// Credencial enviada ao /api/email: com o login com Google disponível, só
  /// vale a conta do Google; sem ele, vale o código de acesso.
  String get emailCredential => googleSignInAvailable ? googleIdToken : emailAccessCode;

  /// Verdadeiro quando os requisitos para envio de e-mails estão satisfeitos.
  bool get canSendEmails =>
      canGeneratePdf &&
      senderEmail.isNotEmpty &&
      emailCredential.isNotEmpty &&
      hasValidEmailColumn &&
      !isSendingEmails;
}

class GeneratorError extends GeneratorState {
  final String message;
  GeneratorError(this.message);
}

class GeneratorSuccess extends GeneratorState {
  final String message;
  GeneratorSuccess(this.message);
}

/// Um destinatário que não recebeu o certificado e o motivo.
class EmailFailure {
  /// Nome da pessoa na planilha (vazio se não houver coluna "nome").
  final String name;
  final String email;
  final EmailFailureKind kind;

  /// Explicação curta do problema.
  final String detail;

  /// Endereço provável, quando o problema parece erro de digitação.
  final String? suggestion;

  const EmailFailure({
    required this.name,
    required this.email,
    required this.kind,
    required this.detail,
    this.suggestion,
  });
}

/// Resumo de um envio em lote com alguma falha, separado por tipo de problema.
class GeneratorEmailReport extends GeneratorState {
  final int sentCount;
  final List<EmailFailure> failures;

  /// Participantes que nem chegaram a ser tentados porque o envio parou
  /// (login/código recusado ou servidor sem configuração).
  final int notAttemptedCount;

  GeneratorEmailReport({
    required this.sentCount,
    required this.failures,
    this.notAttemptedCount = 0,
  });

  List<EmailFailure> ofKind(EmailFailureKind kind) => failures.where((f) => f.kind == kind).toList();
}
