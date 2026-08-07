import 'dart:typed_data';
import 'generator_state.dart';

abstract class GeneratorEvent {}

class LoadFilesEvent extends GeneratorEvent {
  final Uint8List? imageBytes;
  final String? csvContent;
  LoadFilesEvent({this.imageBytes, this.csvContent});
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
  final String? emailSubject;
  final String? emailBody;
  final String? emailColumn;

  UpdateEmailConfigEvent({
    this.senderEmail,
    this.emailSubject,
    this.emailBody,
    this.emailColumn,
  });
}

class LoadEmailConfigEvent extends GeneratorEvent {}

class SendEmailsBatchEvent extends GeneratorEvent {}

class UpdateEmailProgressEvent extends GeneratorEvent {
  final int sentCount;
  final int totalCount;
  UpdateEmailProgressEvent(this.sentCount, this.totalCount);
}
