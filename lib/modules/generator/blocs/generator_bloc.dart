import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:csv/csv.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/cert_generator.dart';
import '../../../core/utils/cert_pdf_generator.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/email_service.dart';
import 'generator_event.dart';
import 'generator_state.dart';

class GeneratorBloc extends Bloc<GeneratorEvent, GeneratorState> {
  GeneratorBloc() : super(GeneratorInitial()) {
    on<LoadFilesEvent>(_onLoadFiles);
    on<LoadBackImageEvent>(_onLoadBackImage);
    on<UpdateTemplateEvent>(_onUpdateTemplate);
    on<UpdateTextPositionEvent>(_onUpdateTextPosition);
    on<SelectPreviewRowEvent>(_onSelectPreviewRow);
    on<UpdatePdfModeEvent>(_onUpdatePdfMode);
    on<GenerateBatchEvent>(_onGenerateBatch);
    on<GeneratePdfBatchEvent>(_onGeneratePdfBatch);
    on<UpdateProgressEvent>(_onUpdateProgress);
    
    // Email events
    on<LoadEmailConfigEvent>(_onLoadEmailConfig);
    on<UpdateEmailConfigEvent>(_onUpdateEmailConfig);
    on<SendEmailsBatchEvent>(_onSendEmailsBatch);
    on<UpdateEmailProgressEvent>(_onUpdateEmailProgress);
    
    // Inicia carregando as configurações
    add(LoadEmailConfigEvent());
  }

  // ─── Handlers ────────────────────────────────────────────────────────────

  void _onLoadFiles(LoadFilesEvent event, Emitter<GeneratorState> emit) {
    // Resolve o estado atual — se ainda não foi inicializado, cria um estado vazio
    final GeneratorLoaded current;
    if (state is GeneratorLoaded) {
      current = state as GeneratorLoaded;
    } else {
      current = GeneratorLoaded(
        csvData: const [],
        csvHeaders: const [],
        mappedData: const [],
      );
    }

    List<List<dynamic>> newCsvData = current.csvData;
    List<String> newHeaders = current.csvHeaders;
    List<Map<String, dynamic>> newMappedData = current.mappedData;

    if (event.csvContent != null) {
      final sanitizedContent = event.csvContent!.replaceAll('\r\n', '\n');
      final delimiter = sanitizedContent.split('\n').first.contains(';') ? ';' : ',';
      final rows = const CsvToListConverter(eol: '\n').convert(
        sanitizedContent,
        fieldDelimiter: delimiter,
      );
      if (rows.isNotEmpty) {
        newCsvData = rows;
        // Remove espaços e caracteres invisíveis (como BOM \ufeff) dos cabeçalhos
        newHeaders = rows.first.map((e) => e.toString().replaceAll(RegExp(r'[\ufeff\u200b]'), '').trim()).toList();
        
        final requiredHeaders = ['nome', 'evento', 'data', 'horas', 'email'];
        final lowerHeaders = newHeaders.map((e) => e.toLowerCase()).toList();
        final missingHeaders = requiredHeaders.where((h) => !lowerHeaders.contains(h)).toList();
        
        if (missingHeaders.isNotEmpty) {
          emit(GeneratorError('O CSV deve conter as colunas obrigatórias: ${missingHeaders.join(', ')}'));
          return;
        }

        newMappedData = [
          for (int i = 1; i < rows.length; i++)
            {
              for (int j = 0; j < newHeaders.length; j++)
                if (j < rows[i].length) newHeaders[j]: rows[i][j],
            }
        ];
      }
      emit(GeneratorSuccess('CSV carregado com sucesso!'));
    }

    if (event.imageBytes != null) {
      emit(GeneratorSuccess('Template carregado com sucesso!'));
    }

    emit(current.copyWith(
      csvData: newCsvData,
      csvHeaders: newHeaders,
      mappedData: newMappedData,
      templateImageBytes: event.imageBytes ?? current.templateImageBytes,
      selectedCsvRowIndex: 0,
    ));
  }


  void _onLoadBackImage(LoadBackImageEvent event, Emitter<GeneratorState> emit) {
    if (state is GeneratorLoaded) {
      final current = state as GeneratorLoaded;
      emit(GeneratorSuccess('Template Verso carregado com sucesso!'));
      emit(current.copyWith(
        backTemplateImageBytes: event.imageBytes,
      ));
    }
  }

  void _onUpdateTemplate(UpdateTemplateEvent event, Emitter<GeneratorState> emit) {
    if (state is GeneratorLoaded) {
      final current = state as GeneratorLoaded;
      if (event.isBack) {
        emit(current.copyWith(
          backTextTemplate: event.textTemplate ?? current.backTextTemplate,
          backFontSize: event.fontSize ?? current.backFontSize,
          backFontFamily: event.fontFamily ?? current.backFontFamily,
          backFontColorValue: event.fontColorValue ?? current.backFontColorValue,
        ));
      } else {
        emit(current.copyWith(
          textTemplate: event.textTemplate ?? current.textTemplate,
          fontSize: event.fontSize ?? current.fontSize,
          fontFamily: event.fontFamily ?? current.fontFamily,
          fontColorValue: event.fontColorValue ?? current.fontColorValue,
        ));
      }
    }
  }

  void _onUpdateTextPosition(UpdateTextPositionEvent event, Emitter<GeneratorState> emit) {
    if (state is GeneratorLoaded) {
      final current = state as GeneratorLoaded;
      if (event.isBack) {
        emit(current.copyWith(
          backTextPositionX: event.dx?.clamp(0.0, 1.0) ?? current.backTextPositionX,
          backTextPositionY: event.dy?.clamp(0.0, 1.0) ?? current.backTextPositionY,
        ));
      } else {
        emit(current.copyWith(
          textPositionX: event.dx?.clamp(0.0, 1.0) ?? current.textPositionX,
          textPositionY: event.dy?.clamp(0.0, 1.0) ?? current.textPositionY,
        ));
      }
    }
  }

  void _onSelectPreviewRow(SelectPreviewRowEvent event, Emitter<GeneratorState> emit) {
    if (state is GeneratorLoaded) {
      final current = state as GeneratorLoaded;
      final idx = event.index.clamp(0, current.mappedData.length - 1);
      emit(current.copyWith(selectedCsvRowIndex: idx));
    }
  }

  void _onUpdatePdfMode(UpdatePdfModeEvent event, Emitter<GeneratorState> emit) {
    if (state is GeneratorLoaded) {
      final current = state as GeneratorLoaded;
      emit(current.copyWith(
        pdfMode: event.mode,
        // Limpa o verso se o usuário volta para frontOnly
        clearBackTemplate: event.mode == PdfMode.frontOnly,
      ));
    }
  }

  void _onUpdateProgress(UpdateProgressEvent event, Emitter<GeneratorState> emit) {
    if (state is GeneratorLoaded) {
      final current = state as GeneratorLoaded;
      emit(current.copyWith(progress: event.progress));
    }
  }

  // ─── EMAIL ───────────────────────────────────────────────────────────────
  Future<void> _onLoadEmailConfig(LoadEmailConfigEvent event, Emitter<GeneratorState> emit) async {
    if (state is GeneratorLoaded) {
      final config = await PreferencesService.loadResendConfig();
      emit((state as GeneratorLoaded).copyWith(
        resendApiKey: config['apiKey'],
        senderEmail: config['senderEmail'],
        emailSubject: config['subject'],
        emailBody: config['body'],
        emailColumn: config['emailColumn'],
      ));
    }
  }

  Future<void> _onUpdateEmailConfig(UpdateEmailConfigEvent event, Emitter<GeneratorState> emit) async {
    if (state is GeneratorLoaded) {
      final current = state as GeneratorLoaded;
      
      final apiKey = event.resendApiKey ?? current.resendApiKey;
      final senderEmail = event.senderEmail ?? current.senderEmail;
      final subject = event.emailSubject ?? current.emailSubject;
      final body = event.emailBody ?? current.emailBody;
      final emailColumn = event.emailColumn ?? current.emailColumn;

      await PreferencesService.saveResendConfig(
        apiKey: apiKey,
        senderEmail: senderEmail,
        subject: subject,
        body: body,
        emailColumn: emailColumn,
      );

      emit(current.copyWith(
        resendApiKey: apiKey,
        senderEmail: senderEmail,
        emailSubject: subject,
        emailBody: body,
        emailColumn: emailColumn,
      ));
    }
  }

  void _onUpdateEmailProgress(UpdateEmailProgressEvent event, Emitter<GeneratorState> emit) {
    if (state is GeneratorLoaded) {
      emit((state as GeneratorLoaded).copyWith(
        emailsSentCount: event.sentCount,
        emailsTotalCount: event.totalCount,
      ));
    }
  }

  Future<void> _onSendEmailsBatch(SendEmailsBatchEvent event, Emitter<GeneratorState> emit) async {
    if (state is! GeneratorLoaded) return;
    final current = state as GeneratorLoaded;

    if (!current.canSendEmails) {
      emit(GeneratorError('Faltam configurações de e-mail ou os requisitos do certificado (Imagem/CSV).'));
      emit(current);
      return;
    }

    emit(current.copyWith(
      isSendingEmails: true, 
      emailsSentCount: 0, 
      emailsTotalCount: current.mappedData.length
    ));

    try {
      int successCount = 0;
      for (int i = 0; i < current.mappedData.length; i++) {
        final row = current.mappedData[i];
        final recipientEmail = row[current.emailColumn]?.toString().trim();
        
        if (recipientEmail == null || recipientEmail.isEmpty || !recipientEmail.contains('@')) {
          // Pula caso não haja email válido nesta linha
          add(UpdateEmailProgressEvent(successCount, current.mappedData.length));
          continue;
        }

        // 1. Gera a imagem do certificado apenas desta linha
        final certBytes = await CertGenerator.generateCertificateImage(
          await decodeImageFromList(current.templateImageBytes!),
          row,
          current.textTemplate,
          current.fontSize,
          current.fontFamily,
          Color(current.fontColorValue),
          textPositionX: current.textPositionX,
          textPositionY: current.textPositionY,
        );

        // 2. Transforma a imagem gerada num PDF
        Uint8List? backBytes;
        if (current.pdfMode != PdfMode.frontOnly && current.backTemplateImageBytes != null) {
          backBytes = current.backTemplateImageBytes;
        }

        final pdfBytes = await CertPdfGenerator.generateSinglePdf(
          frontImageBytes: certBytes,
          backImageBytes: backBytes,
          mode: current.pdfMode,
        );

        // Define o nome do arquivo pdf
        String certName = 'certificado_$i.pdf';
        if (current.csvHeaders.isNotEmpty && row.containsKey(current.csvHeaders.first)) {
          certName = '${row[current.csvHeaders.first]}_certificado.pdf'.replaceAll(RegExp(r'[^a-zA-ZÀ-ÿ0-9_\-\.]'), '_');
        }

        // Substituir variáveis no corpo do email se houver
        String parsedBody = current.emailBody;
        row.forEach((key, value) {
          parsedBody = parsedBody.replaceAll('{$key}', value.toString());
        });

        String parsedSubject = current.emailSubject;
        row.forEach((key, value) {
          parsedSubject = parsedSubject.replaceAll('{$key}', value.toString());
        });

        // 3. Envia via Resend
        final success = await EmailService.sendEmailWithAttachment(
          senderEmail: current.senderEmail,
          toEmail: recipientEmail,
          subject: parsedSubject,
          textBody: parsedBody,
          attachmentName: certName,
          attachmentBytes: pdfBytes,
        );

        if (success) successCount++;
        
        // Atualiza a barra de progresso após enviar
        add(UpdateEmailProgressEvent(successCount, current.mappedData.length));
        
        // Evitar rate limit severo (2 envios por seg na free tier do resend)
        await Future.delayed(const Duration(milliseconds: 550));
      }

      final updatedState = state as GeneratorLoaded;
      emit(updatedState.copyWith(isSendingEmails: false));
      emit(GeneratorSuccess('E-mails processados: $successCount envios com sucesso.'));
    } catch (e) {
      final updatedState = state as GeneratorLoaded;
      emit(GeneratorError('Erro durante envio de e-mails: $e'));
      emit(updatedState.copyWith(isSendingEmails: false));
    }
  }

  // ─── ZIP (PNGs) ───────────────────────────────────────────────────────────
  Future<void> _onGenerateBatch(GenerateBatchEvent event, Emitter<GeneratorState> emit) async {
    if (state is! GeneratorLoaded) return;
    final current = state as GeneratorLoaded;
    if (!current.canGenerateZip) {
      emit(GeneratorError('Faltam dados ou imagem base.'));
      emit(current);
      return;
    }

    emit(current.copyWith(isGenerating: true, progress: 0.0));

    final receivePort = ReceivePort();
    final args = <String, dynamic>{
      'sendPort': receivePort.sendPort,
      'data': current.mappedData,
      'headers': current.csvHeaders,
      'imgBytes': current.templateImageBytes,
      'backImgBytes': current.backTemplateImageBytes,
      'textTemplate': current.textTemplate,
      'fontSize': current.fontSize,
      'fontFamily': current.fontFamily,
      'fontColor': current.fontColorValue,
      'textPositionX': current.textPositionX,
      'textPositionY': current.textPositionY,
      'backTextTemplate': current.backTextTemplate,
      'backFontSize': current.backFontSize,
      'backFontFamily': current.backFontFamily,
      'backFontColor': current.backFontColorValue,
      'backTextPositionX': current.backTextPositionX,
      'backTextPositionY': current.backTextPositionY,
      'pdfMode': current.pdfMode.name,
    };

    await Isolate.spawn(_generateZipWorker, args);

    Uint8List? zipBytes;
    await for (final msg in receivePort) {
      if (msg is double) {
        add(UpdateProgressEvent(msg));
      } else if (msg is Uint8List) {
        zipBytes = msg;
        receivePort.close();
      } else if (msg is String && msg.startsWith('ERROR:')) {
        emit(GeneratorError(msg));
        receivePort.close();
      }
    }

    if (zipBytes != null) {
      await _shareFile(zipBytes, 'certificados.zip', 'Aqui estão os certificados gerados!', emit, current);
    }

    add(UpdateProgressEvent(1.0));
    emit(current.copyWith(isGenerating: false, progress: 1.0));
  }

  // ─── PDF ─────────────────────────────────────────────────────────────────
  Future<void> _onGeneratePdfBatch(GeneratePdfBatchEvent event, Emitter<GeneratorState> emit) async {
    if (state is! GeneratorLoaded) return;
    final current = state as GeneratorLoaded;
    if (!current.canGeneratePdf) {
      emit(GeneratorError('Para gerar o PDF, carregue todos os arquivos necessários.'));
      emit(current);
      return;
    }

    emit(current.copyWith(isGenerating: true, progress: 0.0));

    final receivePort = ReceivePort();
    final args = <String, dynamic>{
      'sendPort': receivePort.sendPort,
      'data': current.mappedData,
      'headers': current.csvHeaders,
      'frontImgBytes': current.templateImageBytes,
      'backImgBytes': current.backTemplateImageBytes,
      'textTemplate': current.textTemplate,
      'fontSize': current.fontSize,
      'fontFamily': current.fontFamily,
      'fontColor': current.fontColorValue,
      'textPositionX': current.textPositionX,
      'textPositionY': current.textPositionY,
      'backTextTemplate': current.backTextTemplate,
      'backFontSize': current.backFontSize,
      'backFontFamily': current.backFontFamily,
      'backFontColor': current.backFontColorValue,
      'backTextPositionX': current.backTextPositionX,
      'backTextPositionY': current.backTextPositionY,
      'pdfMode': current.pdfMode.name,
    };

    await Isolate.spawn(generatePdfWorker, args);

    Uint8List? pdfBytes;
    await for (final msg in receivePort) {
      if (msg is double) {
        add(UpdateProgressEvent(msg));
      } else if (msg is Uint8List) {
        pdfBytes = msg;
        receivePort.close();
      } else if (msg is String && msg.startsWith('ERROR:')) {
        emit(GeneratorError('Erro ao gerar PDF: $msg'));
        receivePort.close();
      }
    }

    if (pdfBytes != null) {
      await _shareFile(pdfBytes, 'certificados.pdf', 'Certificados em PDF', emit, current);
    }

    add(UpdateProgressEvent(1.0));
    emit(current.copyWith(isGenerating: false, progress: 1.0));
  }

  // ─── Helper compartilhado ────────────────────────────────────────────────
  Future<void> _shareFile(
    Uint8List bytes,
    String filename,
    String text,
    Emitter<GeneratorState> emit,
    GeneratorLoaded fallbackState,
  ) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(bytes);
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(file.path)], text: text);
        emit(GeneratorSuccess('Arquivo gerado e pronto para compartilhamento!'));
      } else {
        // Desktop support (Linux, Windows, macOS)
        // O FilePicker precisa rodar no contexto de UI, mas como estamos no BLoC, usamos a chamada da API
        // Se a lib não suportar no isolado, isso pode falhar. No BLoC ainda estamos na thread principal.
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Salvar $filename',
          fileName: filename,
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);
          emit(GeneratorSuccess('Arquivo salvo com sucesso em:\n$outputFile'));
        }
      }
    } catch (e) {
      emit(GeneratorError('Erro ao compartilhar ou salvar: $e'));
    }
  }
}

// ─── Isolate worker: ZIP ─────────────────────────────────────────────────────
void _generateZipWorker(Map<String, dynamic> args) async {
  try {
    final SendPort sendPort = args['sendPort'];
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

    for (int i = 0; i < data.length; i++) {
      final row = data[i];
      
      String baseName = 'certificado_$i';
      if (headers.isNotEmpty && row.containsKey(headers.first)) {
        baseName = row[headers.first]?.toString() ?? baseName;
      }
      final cleanName = baseName.replaceAll(RegExp(r'[^a-zA-ZÀ-ÿ0-9_\-]'), '_');

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

      sendPort.send((i + 1) / data.length);
    }

    final zipData = ZipEncoder().encode(archive);
    sendPort.send(Uint8List.fromList(zipData));
  } catch (e) {
    final SendPort sendPort = args['sendPort'];
    sendPort.send('ERROR:$e');
  }
}
