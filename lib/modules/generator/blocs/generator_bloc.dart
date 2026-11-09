import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/cert_generator.dart';
import '../../../core/utils/certificate_file_names.dart';
import '../../../core/utils/participant_table_parser.dart';
import '../services/certificate_zip_job.dart';
import '../../../core/utils/cert_pdf_generator.dart';
import '../../../core/utils/certificate_fonts.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/email_service.dart';
import 'generator_event.dart';
import 'generator_state.dart';

/// Limite de anexo aceito pelo /api/email (ver api/email.js).
const kMaxEmailAttachmentBytes = 3 * 1024 * 1024;

/// Limite diário aproximado de envios de uma conta Gmail.
const kGmailDailyLimit = 500;

final _emailRegex = RegExp(r'^[^\s@<>,;"]+@[^\s@<>,;"]+\.[^\s@<>,;"]+$');

class GeneratorBloc extends Bloc<GeneratorEvent, GeneratorState> {
  GeneratorBloc() : super(GeneratorInitial()) {
    on<LoadFilesEvent>(_onLoadFiles);
    on<LoadBackImageEvent>(_onLoadBackImage);
    on<UpdateTemplateEvent>(_onUpdateTemplate);
    on<UpdateTextPositionEvent>(_onUpdateTextPosition);
    on<SelectPreviewRowEvent>(_onSelectPreviewRow);
    on<UpdateAcademicFieldEvent>(_onUpdateAcademicField);
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

  /// Último [GeneratorLoaded] emitido. Mensagens (sucesso/erro) substituem o
  /// estado por um instante; os handlers partem sempre dos dados mais recentes.
  GeneratorLoaded? _lastLoaded;

  GeneratorLoaded? get _loaded =>
      state is GeneratorLoaded ? state as GeneratorLoaded : _lastLoaded;

  @override
  void onChange(Change<GeneratorState> change) {
    super.onChange(change);
    final next = change.nextState;
    if (next is GeneratorLoaded) _lastLoaded = next;
  }

  // ─── Handlers ────────────────────────────────────────────────────────────

  void _onLoadFiles(LoadFilesEvent event, Emitter<GeneratorState> emit) {
    // Resolve o estado atual — se ainda não foi inicializado, cria um estado vazio
    final GeneratorLoaded current;
    if (_loaded != null) {
      current = _loaded!;
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

    if (event.csvContent != null || event.tableRows != null) {
      try {
        final parsed = event.tableRows != null
            ? ParticipantTableParser.parseRows(event.tableRows!)
            : ParticipantTableParser.parse(event.csvContent!);
        newCsvData = parsed.csvData;
        newHeaders = parsed.headers;
        newMappedData = parsed.mappedData;
      } on FormatException catch (error) {
        emit(GeneratorError(error.message));
        // CSV inválido não apaga o arquivo ou as alterações anteriores.
        emit(current);
        return;
      } on Exception {
        emit(GeneratorError(
          'Não foi possível ler os participantes. Confira o formato CSV/TSV/Excel.',
        ));
        emit(current);
        return;
      }
      emit(GeneratorSuccess('Dados dos participantes carregados com sucesso!'));
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
    final current = _loaded;
    if (current != null) {
      emit(GeneratorSuccess('Template Verso carregado com sucesso!'));
      emit(current.copyWith(
        backTemplateImageBytes: event.imageBytes,
      ));
    }
  }

  void _onUpdateTemplate(UpdateTemplateEvent event, Emitter<GeneratorState> emit) {
    final current = _loaded;
    if (current != null) {
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
    final current = _loaded;
    if (current != null) {
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

  /// Atualiza apenas a linha selecionada, preservando os demais certificados.
  /// Cabeçalhos opcionais podem ser acrescentados mesmo em CSVs antigos.
  void _onUpdateAcademicField(
    UpdateAcademicFieldEvent event,
    Emitter<GeneratorState> emit,
  ) {
    final current = _loaded;
    if (current == null ||
        current.isGenerating ||
        current.isSendingEmails ||
        event.rowIndex < 0 ||
        event.rowIndex >= current.mappedData.length) {
      return;
    }

    final column = event.field.column;
    final headers = List<String>.of(current.csvHeaders);
    if (!headers.contains(column)) headers.add(column);
    final columnIndex = headers.indexOf(column);

    final mappedData = List<Map<String, dynamic>>.of(current.mappedData);
    final row = Map<String, dynamic>.of(mappedData[event.rowIndex]);
    row[column] = event.value;
    mappedData[event.rowIndex] = row;

    // Mantém csvData coerente com os dados editados na memória.
    final csvData = current.csvData
        .map((values) => List<dynamic>.of(values))
        .toList();
    if (csvData.isNotEmpty) {
      while (csvData.first.length <= columnIndex) {
        csvData.first.add('');
      }
      csvData.first[columnIndex] = column;
      final sourceRowIndex = event.rowIndex + 1;
      if (sourceRowIndex < csvData.length) {
        final sourceRow = csvData[sourceRowIndex];
        while (sourceRow.length <= columnIndex) {
          sourceRow.add('');
        }
        sourceRow[columnIndex] = event.value;
      }
    }

    emit(current.copyWith(
      csvData: csvData,
      csvHeaders: headers,
      mappedData: mappedData,
    ));
  }

  void _onSelectPreviewRow(SelectPreviewRowEvent event, Emitter<GeneratorState> emit) {
    final current = _loaded;
    if (current != null) {
      final idx = event.index.clamp(0, current.mappedData.length - 1);
      emit(current.copyWith(selectedCsvRowIndex: idx));
    }
  }

  void _onUpdatePdfMode(UpdatePdfModeEvent event, Emitter<GeneratorState> emit) {
    final current = _loaded;
    if (current != null) {
      emit(current.copyWith(
        pdfMode: event.mode,
        // Limpa o verso se o usuário volta para frontOnly
        clearBackTemplate: event.mode == PdfMode.frontOnly,
      ));
    }
  }

  void _onUpdateProgress(UpdateProgressEvent event, Emitter<GeneratorState> emit) {
    final current = _loaded;
    if (current != null) {
      emit(current.copyWith(progress: event.progress));
    }
  }

  // ─── EMAIL ───────────────────────────────────────────────────────────────
  Future<void> _onLoadEmailConfig(LoadEmailConfigEvent event, Emitter<GeneratorState> emit) async {
    if (_loaded != null) {
      final config = await PreferencesService.loadEmailConfig();
      emit(_loaded!.copyWith(
        senderEmail: config['senderEmail'],
        emailAccessCode: config['accessCode'],
        emailSubject: config['subject'],
        emailBody: config['body'],
        emailColumn: config['emailColumn'],
      ));
    }
  }

  Future<void> _onUpdateEmailConfig(UpdateEmailConfigEvent event, Emitter<GeneratorState> emit) async {
    final current = _loaded;
    if (current != null) {
      
      final senderEmail = event.senderEmail ?? current.senderEmail;
      final accessCode = event.emailAccessCode ?? current.emailAccessCode;
      final subject = event.emailSubject ?? current.emailSubject;
      final body = event.emailBody ?? current.emailBody;
      final emailColumn = event.emailColumn ?? current.emailColumn;

      // Atualiza o estado antes de salvar: depois do await o estado pode ter
      // mudado (ex.: novo CSV) e não deve ser sobrescrito.
      emit(current.copyWith(
        senderEmail: senderEmail,
        emailAccessCode: accessCode,
        emailSubject: subject,
        emailBody: body,
        emailColumn: emailColumn,
      ));

      await PreferencesService.saveEmailConfig(
        senderEmail: senderEmail,
        accessCode: accessCode,
        subject: subject,
        body: body,
        emailColumn: emailColumn,
      );
    }
  }

  void _onUpdateEmailProgress(UpdateEmailProgressEvent event, Emitter<GeneratorState> emit) {
    if (_loaded != null) {
      emit(_loaded!.copyWith(
        emailsSentCount: event.sentCount,
        emailsTotalCount: event.totalCount,
      ));
    }
  }

  Future<void> _onSendEmailsBatch(SendEmailsBatchEvent event, Emitter<GeneratorState> emit) async {
    final current = _loaded;
    if (current == null) return;

    if (!current.hasValidEmailColumn) {
      emit(GeneratorError(
        'A coluna de destinatários "${current.emailColumn}" não existe no CSV atual. '
        'Escolha uma coluna válida na aba E-mails.',
      ));
      emit(current);
      return;
    }

    if (!current.canSendEmails) {
      emit(GeneratorError('Faltam configurações de e-mail ou os requisitos do certificado (Imagem/CSV).'));
      emit(current);
      return;
    }

    if (!_emailRegex.hasMatch(current.senderEmail.trim())) {
      emit(GeneratorError('Informe um e-mail de resposta válido (ex.: contato@instituicao.edu.br).'));
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
      int failureCount = 0;
      String? lastError;
      final failedRecipients = <String>[];
      await loadCertificateFonts({current.fontFamily, current.backFontFamily});
      // As artes são decodificadas uma vez só para o lote inteiro.
      final frontTemplate = await decodeImageFromList(current.templateImageBytes!);
      final backTemplate =
          current.pdfMode != PdfMode.frontOnly && current.backTemplateImageBytes != null
              ? await decodeImageFromList(current.backTemplateImageBytes!)
              : null;
      final fileBaseNames = CertificateFileNames.uniqueBaseNames(
        current.mappedData,
        current.csvHeaders,
      );
      for (int i = 0; i < current.mappedData.length; i++) {
        final row = current.mappedData[i];
        final recipientEmail = row[current.emailColumn]?.toString().trim();
        
        if (recipientEmail == null || !_emailRegex.hasMatch(recipientEmail)) {
          // Pula caso não haja email válido nesta linha
          add(UpdateEmailProgressEvent(successCount, current.mappedData.length));
          continue;
        }

        // 1. Gera o PDF do certificado desta linha, já comprimido para o e-mail
        final pdfBytes = await _buildEmailPdf(current, row, frontTemplate, backTemplate);

        // O servidor recusa anexos acima de 3 MB: avisa antes de tentar o envio.
        if (pdfBytes.length > kMaxEmailAttachmentBytes) {
          failureCount++;
          failedRecipients.add(recipientEmail);
          lastError = 'mesmo comprimido, o certificado ficou com '
              '${(pdfBytes.length / (1024 * 1024)).toStringAsFixed(1)} MB (máximo 3 MB). '
              'Use uma imagem de template com menos pixels.';
          add(UpdateEmailProgressEvent(successCount, current.mappedData.length));
          continue;
        }

        // Evita nomes duplicados entre participantes homônimos.
        final certName = '${fileBaseNames[i]}_certificado.pdf';

        // Substituir variáveis no corpo do email se houver
        String parsedBody = current.emailBody;
        row.forEach((key, value) {
          parsedBody = parsedBody.replaceAll('{$key}', value.toString());
        });

        String parsedSubject = current.emailSubject;
        row.forEach((key, value) {
          parsedSubject = parsedSubject.replaceAll('{$key}', value.toString());
        });

        // 3. Envia via Gmail SMTP
        final result = await EmailService.sendEmailWithAttachment(
          accessCode: current.emailAccessCode.trim(),
          replyTo: current.senderEmail.trim(),
          toEmail: recipientEmail,
          subject: parsedSubject,
          textBody: parsedBody,
          attachmentName: certName,
          attachmentBytes: pdfBytes,
        );

        if (result.success) {
          successCount++;
        } else {
          failureCount++;
          failedRecipients.add(recipientEmail);
          lastError = result.error;
          // Código inválido ou servidor sem configuração: os próximos envios também falhariam.
          if (result.unauthorized) break;
        }
        
        // Atualiza a barra de progresso após enviar
        add(UpdateEmailProgressEvent(successCount, current.mappedData.length));
        
        // Evitar rate limit (Gmail tem limite de 500 envios/dia)
        await Future.delayed(const Duration(milliseconds: 550));
      }
      frontTemplate.dispose();
      backTemplate?.dispose();

      final updatedState = _loaded ?? current;
      emit(updatedState.copyWith(isSendingEmails: false));
      if (failureCount == 0) {
        emit(GeneratorSuccess('E-mails processados: $successCount envios com sucesso.'));
      } else {
        final shown = failedRecipients.take(5).join(', ');
        final more = failedRecipients.length > 5 ? ' e mais ${failedRecipients.length - 5}' : '';
        emit(GeneratorError(
          '$successCount e-mail(s) enviados, $failureCount com falha ($shown$more). Último erro: $lastError',
        ));
      }
      emit(updatedState.copyWith(isSendingEmails: false));
    } catch (e) {
      final updatedState = _loaded ?? current;
      emit(GeneratorError('Erro durante envio de e-mails: $e'));
      emit(updatedState.copyWith(isSendingEmails: false));
    }
  }

  /// Gera o PDF de um participante para anexar no e-mail.
  ///
  /// As páginas vão em JPEG, reduzidas até caber no limite do servidor.
  Future<Uint8List> _buildEmailPdf(
    GeneratorLoaded current,
    Map<String, dynamic> row,
    ui.Image frontTemplate,
    ui.Image? backTemplate,
  ) async {
    final front = await CertGenerator.renderCertificate(
      frontTemplate,
      row,
      current.textTemplate,
      current.fontSize,
      current.fontFamily,
      Color(current.fontColorValue),
      textPositionX: current.textPositionX,
      textPositionY: current.textPositionY,
    );
    final back = backTemplate == null
        ? null
        : await CertGenerator.renderCertificate(
            backTemplate,
            row,
            current.backTextTemplate,
            current.backFontSize,
            current.backFontFamily,
            Color(current.backFontColorValue),
            textPositionX: current.backTextPositionX,
            textPositionY: current.backTextPositionY,
          );

    final pdfBytes = await CertPdfGenerator.generateSinglePdfWithinLimit(
      front: front,
      back: back,
      mode: current.pdfMode,
      maxBytes: kMaxEmailAttachmentBytes,
    );
    front.dispose();
    back?.dispose();
    return pdfBytes;
  }

  // ─── ZIP (PNGs) ───────────────────────────────────────────────────────────
  Future<void> _onGenerateBatch(GenerateBatchEvent event, Emitter<GeneratorState> emit) async {
    final current = _loaded;
    if (current == null) return;
    if (!current.canGenerateZip) {
      emit(GeneratorError('Faltam dados ou imagem base.'));
      emit(current);
      return;
    }

    emit(current.copyWith(isGenerating: true, progress: 0.0));

    final args = <String, dynamic>{
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

    final zipBytes = await _runJob(
      args,
      job: generateZipJob,
      worker: generateZipWorker,
      onError: (msg) => emit(GeneratorError('Erro ao gerar ZIP: $msg')),
    );

    if (zipBytes != null) {
      await _shareFile(zipBytes, _timestampedName('certificados', 'zip'), 'Aqui estão os certificados gerados!', emit, current);
    }

    add(UpdateProgressEvent(1.0));
    // Usa o estado mais recente: arquivos ou textos alterados durante a
    // geração não podem voltar ao que eram quando ela começou.
    emit((_loaded ?? current).copyWith(isGenerating: false, progress: 1.0));
  }

  // ─── PDF ─────────────────────────────────────────────────────────────────
  Future<void> _onGeneratePdfBatch(GeneratePdfBatchEvent event, Emitter<GeneratorState> emit) async {
    final current = _loaded;
    if (current == null) return;
    if (!current.canGeneratePdf) {
      emit(GeneratorError('Para gerar o PDF, carregue todos os arquivos necessários.'));
      emit(current);
      return;
    }

    emit(current.copyWith(isGenerating: true, progress: 0.0));

    final args = <String, dynamic>{
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

    final pdfBytes = await _runJob(
      args,
      job: generatePdfJob,
      worker: generatePdfWorker,
      onError: (msg) => emit(GeneratorError('Erro ao gerar PDF: $msg')),
    );

    if (pdfBytes != null) {
      await _shareFile(pdfBytes, _timestampedName('certificados', 'pdf'), 'Certificados em PDF', emit, current);
    }

    add(UpdateProgressEvent(1.0));
    // Usa o estado mais recente: arquivos ou textos alterados durante a
    // geração não podem voltar ao que eram quando ela começou.
    emit((_loaded ?? current).copyWith(isGenerating: false, progress: 1.0));
  }

  // ─── Execução da geração ────────────────────────────────────────────────
  /// Roda a geração em um Isolate (app nativo) ou na thread principal (Web,
  /// onde `Isolate.spawn` não existe). Devolve os bytes gerados ou null.
  Future<Uint8List?> _runJob(
    Map<String, dynamic> args, {
    required Future<void> Function(Map<String, dynamic> args, void Function(Object message) send) job,
    required void Function(Map<String, dynamic> args) worker,
    required void Function(String message) onError,
  }) async {
    // Deixa as fontes do texto carregadas antes de começar a geração.
    await loadCertificateFonts({
      args['fontFamily'] as String,
      if (args['backFontFamily'] != null) args['backFontFamily'] as String,
    });

    Uint8List? result;
    void handle(Object? msg) {
      if (msg is double) {
        add(UpdateProgressEvent(msg));
      } else if (msg is Uint8List) {
        result = msg;
      } else if (msg is String && msg.startsWith('ERROR:')) {
        onError(msg.substring('ERROR:'.length));
      }
    }

    if (kIsWeb) {
      await job(args, handle);
      return result;
    }

    final receivePort = ReceivePort();
    await Isolate.spawn(worker, {...args, 'sendPort': receivePort.sendPort});
    await for (final msg in receivePort) {
      handle(msg);
      if (msg is Uint8List || (msg is String && msg.startsWith('ERROR:'))) {
        receivePort.close();
      }
    }
    return result;
  }

  // ─── Helper compartilhado ────────────────────────────────────────────────
  /// Nome com data e hora, para o arquivo novo não se confundir com downloads anteriores.
  static String _timestampedName(String base, String ext) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${base}_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}.$ext';
  }

  Future<void> _shareFile(
    Uint8List bytes,
    String filename,
    String text,
    Emitter<GeneratorState> emit,
    GeneratorLoaded fallbackState,
  ) async {
    try {
      if (kIsWeb) {
        // Na Web o file_picker cria um Blob e dispara o download no navegador.
        await FilePicker.platform.saveFile(fileName: filename, bytes: bytes);
        emit(GeneratorSuccess('Download de $filename iniciado.'));
      } else if (Platform.isAndroid || Platform.isIOS) {
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
