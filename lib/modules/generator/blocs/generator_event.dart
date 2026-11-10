import 'dart:typed_data';
import 'generator_state.dart';

abstract class GeneratorEvent {}

class LoadFilesEvent extends GeneratorEvent {
  final Uint8List? imageBytes;
  final String? csvContent;
  final List<List<dynamic>>? tableRows;
  LoadFilesEvent({this.imageBytes, this.csvContent, this.tableRows});
}

class LoadBackImageEvent extends GeneratorEvent {
  final Uint8List imageBytes;
  LoadBackImageEvent(this.imageBytes);
}

class UpdateTemplateEvent extends GeneratorEvent {
  final String? textTemplate;
  final double? fontSize;
  final String? fontFamily;
  final int? fontColorValue;
  final bool isBack;

  UpdateTemplateEvent({
    this.textTemplate,
    this.fontSize,
    this.fontFamily,
    this.fontColorValue,
    this.isBack = false,
  });
}

class UpdateTextPositionEvent extends GeneratorEvent {
  /// Valores normalizados entre 0.0 e 1.0
  final double? dx;
  final double? dy;
  final bool isBack;
  UpdateTextPositionEvent({this.dx, this.dy, this.isBack = false});
}

/// Campos complementares do certificado, por participante.
enum AcademicField {
  orientador('orientador'),
  emailOrientador('email_orientador'),
  nomeTrabalho('nome_trabalho');

  const AcademicField(this.column);
  final String column;
}

/// Atualiza um único campo de uma linha; nunca altera o CSV original em disco.
class UpdateAcademicFieldEvent extends GeneratorEvent {
  final int rowIndex;
  final AcademicField field;
  final String value;

  UpdateAcademicFieldEvent({
    required this.rowIndex,
    required this.field,
    required this.value,
  });
}

class SelectPreviewRowEvent extends GeneratorEvent {
  final int index;
  SelectPreviewRowEvent(this.index);
}

class UpdatePdfModeEvent extends GeneratorEvent {
  final PdfMode mode;
  UpdatePdfModeEvent(this.mode);
}

/// Gera um ZIP com os PNGs de todos os certificados
class GenerateBatchEvent extends GeneratorEvent {}

/// Gera um PDF com frente e/ou verso de todos os certificados
class GeneratePdfBatchEvent extends GeneratorEvent {}

class UpdateProgressEvent extends GeneratorEvent {
  final double progress;
  UpdateProgressEvent(this.progress);
}

class UpdateEmailConfigEvent extends GeneratorEvent {
  final String? senderEmail;
  final String? emailAccessCode;
  final String? emailSubject;
  final String? emailBody;
  final String? emailColumn;

  UpdateEmailConfigEvent({
    this.senderEmail,
    this.emailAccessCode,
    this.emailSubject,
    this.emailBody,
    this.emailColumn,
  });
}

class LoadEmailConfigEvent extends GeneratorEvent {}

/// Resultado do login com Google: [available] diz se o servidor oferece o
/// login; [email]/[idToken] ficam vazios quando ninguém está conectado.
class UpdateGoogleSessionEvent extends GeneratorEvent {
  final bool available;
  final String email;
  final String idToken;

  UpdateGoogleSessionEvent({required this.available, this.email = '', this.idToken = ''});
}

class SendEmailsBatchEvent extends GeneratorEvent {}

class UpdateEmailProgressEvent extends GeneratorEvent {
  final int sentCount;
  final int totalCount;
  UpdateEmailProgressEvent(this.sentCount, this.totalCount);
}
