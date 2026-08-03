import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:csv/csv.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/cert_generator.dart';
import '../../../core/utils/cert_pdf_generator.dart';
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
  }

  // ─── Handlers ────────────────────────────────────────────────────────────

  void _onLoadFiles(LoadFilesEvent event, Emitter<GeneratorState> emit) {
    if (state is GeneratorInitial || state is GeneratorError) {
      emit(GeneratorLoaded(
        csvData: const [],
        csvHeaders: const [],
        mappedData: const [],
      ));
    }

    if (state is GeneratorLoaded) {
      final current = state as GeneratorLoaded;

      List<List<dynamic>> newCsvData = current.csvData;
      List<String> newHeaders = current.csvHeaders;
      List<Map<String, dynamic>> newMappedData = current.mappedData;

      if (event.csvContent != null) {
        final rows = const CsvToListConverter().convert(event.csvContent!);
        if (rows.isNotEmpty) {
          newCsvData = rows;
          newHeaders = rows.first.map((e) => e.toString()).toList();
          newMappedData = [
            for (int i = 1; i < rows.length; i++)
              {
                for (int j = 0; j < newHeaders.length; j++)
                  if (j < rows[i].length) newHeaders[j]: rows[i][j],
              }
          ];
        }
      }

      emit(current.copyWith(
        csvData: newCsvData,
        csvHeaders: newHeaders,
        mappedData: newMappedData,
        templateImageBytes: event.imageBytes ?? current.templateImageBytes,
        selectedCsvRowIndex: 0,
      ));
    }
  }

  void _onLoadBackImage(LoadBackImageEvent event, Emitter<GeneratorState> emit) {
    if (state is GeneratorLoaded) {
      final current = state as GeneratorLoaded;
      emit(current.copyWith(backTemplateImageBytes: event.imageBytes));
    }
  }

  void _onUpdateTemplate(UpdateTemplateEvent event, Emitter<GeneratorState> emit) {
    if (state is GeneratorLoaded) {
      final current = state as GeneratorLoaded;
      emit(current.copyWith(
        textTemplate: event.textTemplate ?? current.textTemplate,
        fontSize: event.fontSize ?? current.fontSize,
        fontFamily: event.fontFamily ?? current.fontFamily,
        fontColorValue: event.fontColorValue ?? current.fontColorValue,
      ));
    }
  }

  void _onUpdateTextPosition(UpdateTextPositionEvent event, Emitter<GeneratorState> emit) {
    if (state is GeneratorLoaded) {
      final current = state as GeneratorLoaded;
      emit(current.copyWith(
        textPositionX: event.dx?.clamp(0.0, 1.0) ?? current.textPositionX,
        textPositionY: event.dy?.clamp(0.0, 1.0) ?? current.textPositionY,
      ));
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
      'textTemplate': current.textTemplate,
      'fontSize': current.fontSize,
      'fontFamily': current.fontFamily,
      'fontColor': current.fontColorValue,
      'textPositionX': current.textPositionX,
      'textPositionY': current.textPositionY,
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
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: text);
    } catch (e) {
      emit(GeneratorError('Erro ao compartilhar: $e'));
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

    final codec = await ui.instantiateImageCodec(imgBytes);
    final frameInfo = await codec.getNextFrame();
    final ui.Image templateImage = frameInfo.image;

    final archive = Archive();

    for (int i = 0; i < data.length; i++) {
      final row = data[i];
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

      String certName = 'certificado_$i';
      if (headers.isNotEmpty && row.containsKey(headers.first)) {
        certName = row[headers.first]?.toString() ?? certName;
      }
      final cleanName = certName.replaceAll(RegExp(r'[^a-zA-ZÀ-ÿ0-9_\-]'), '_');

      archive.addFile(ArchiveFile('$cleanName.png', certBytes.length, certBytes));
      sendPort.send((i + 1) / data.length);
    }

    final zipData = ZipEncoder().encode(archive);
    sendPort.send(Uint8List.fromList(zipData));
  } catch (e) {
    final SendPort sendPort = args['sendPort'];
    sendPort.send('ERROR:$e');
  }
}
