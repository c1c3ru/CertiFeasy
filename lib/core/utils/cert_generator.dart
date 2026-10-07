import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'rich_text_markup.dart';

abstract class ContentBlock {
  Size layout(double maxWidth, TextStyle style);
  void paint(Canvas canvas, Offset offset, TextStyle style, Paint gridPaint);
}

class TextBlock extends ContentBlock {
  final List<MarkupParagraph> paragraphs;
  final List<TextPainter> _painters = [];
  double _width = 0;
  TextBlock(this.paragraphs);

  @override
  Size layout(double maxWidth, TextStyle style) {
    _painters.clear();
    _width = 0;
    for (final p in paragraphs) {
      final painter = TextPainter(
        text: p.toSpan(style),
        textDirection: TextDirection.ltr,
        textAlign: p.textAlign,
      )..layout(maxWidth: maxWidth);
      _painters.add(painter);
      _width = math.max(_width, painter.width);
    }
    // Linhas alinhadas à esquerda/direita/justificadas usam a largura do bloco
    // para que o alinhamento seja relativo às demais linhas.
    for (var i = 0; i < paragraphs.length; i++) {
      if (paragraphs[i].align != MarkupAlign.center) {
        _painters[i].layout(minWidth: _width, maxWidth: _width);
      }
    }
    final height = _painters.fold<double>(0, (h, p) => h + p.height);
    return Size(_width, height);
  }

  @override
  void paint(Canvas canvas, Offset offset, TextStyle style, Paint gridPaint) {
    var y = offset.dy;
    for (final painter in _painters) {
      painter.paint(canvas, Offset(offset.dx + (_width - painter.width) / 2, y));
      y += painter.height;
    }
  }
}

class TableBlock extends ContentBlock {
  final List<List<MarkupParagraph>> rows;
  List<double>? _colWidths;
  List<double>? _rowHeights;
  Size? _size;

  TableBlock(this.rows);

  @override
  Size layout(double maxWidth, TextStyle style) {
    int numCols = 0;
    for (var r in rows) {
      if (r.length > numCols) numCols = r.length;
    }

    _colWidths = List.filled(numCols, 0.0);
    _rowHeights = List.filled(rows.length, 0.0);
    
    // Usamos padding proporcional ao tamanho da fonte
    final cellPadding = style.fontSize! * 0.5;

    // Mede cada célula
    for (int r = 0; r < rows.length; r++) {
      for (int c = 0; c < rows[r].length; c++) {
        final painter = TextPainter(
          text: rows[r][c].toSpan(style),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        painter.layout();
        
        if (painter.width > _colWidths![c]) _colWidths![c] = painter.width;
        if (painter.height > _rowHeights![r]) _rowHeights![r] = painter.height;
      }
    }

    // Adiciona padding
    for (int c = 0; c < numCols; c++) _colWidths![c] += cellPadding * 2;
    for (int r = 0; r < rows.length; r++) _rowHeights![r] += cellPadding * 2;

    double totalWidth = _colWidths!.fold(0.0, (a, b) => a + b);
    double totalHeight = _rowHeights!.fold(0.0, (a, b) => a + b);

    _size = Size(totalWidth, totalHeight);
    return _size!;
  }

  @override
  void paint(Canvas canvas, Offset offset, TextStyle style, Paint gridPaint) {
    if (_size == null) return;
    
    final rect = offset & _size!;
    canvas.drawRect(rect, gridPaint);

    double currentY = offset.dy;
    for (int r = 0; r < rows.length; r++) {
      currentY += _rowHeights![r];
      if (r < rows.length - 1) {
        canvas.drawLine(Offset(offset.dx, currentY), Offset(offset.dx + _size!.width, currentY), gridPaint);
      }
    }

    double currentX = offset.dx;
    for (int c = 0; c < _colWidths!.length; c++) {
      currentX += _colWidths![c];
      if (c < _colWidths!.length - 1) {
        canvas.drawLine(Offset(currentX, offset.dy), Offset(currentX, offset.dy + _size!.height), gridPaint);
      }
    }

    currentY = offset.dy;
    for (int r = 0; r < rows.length; r++) {
      currentX = offset.dx;
      for (int c = 0; c < rows[r].length; c++) {
        final painter = TextPainter(
          text: rows[r][c].toSpan(style),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        painter.layout();

        final textOffset = Offset(
          currentX + (_colWidths![c] - painter.width) / 2,
          currentY + (_rowHeights![r] - painter.height) / 2,
        );
        painter.paint(canvas, textOffset);

        currentX += _colWidths![c];
      }
      currentY += _rowHeights![r];
    }
  }
}

class CertGenerator {
  /// Adiciona o bloco de texto ignorando linhas vazias no fim, como antes.
  static void _addTextBlock(List<ContentBlock> blocks, List<MarkupParagraph> paragraphs) {
    final list = List.of(paragraphs);
    while (list.isNotEmpty && list.last.plainText.trim().isEmpty) {
      list.removeLast();
    }
    if (list.isNotEmpty) blocks.add(TextBlock(list));
  }

  /// Largura de arte em que o tamanho da fonte vale em pixels.
  ///
  /// O texto acompanha a largura da arte: numa arte de 3000 px a fonte sai
  /// 3 vezes maior que numa de 1000 px. Assim a prévia na tela e o
  /// certificado gerado na resolução original ficam na mesma proporção.
  static const double textReferenceWidth = 1000;

  static void drawCertificateContent(
    Canvas canvas,
    Size size,
    String parsedText,
    double fontSize,
    String fontFamily,
    Color fontColor, {
    double textPositionX = 0.5,
    double textPositionY = 0.5,
  }) {
    if (size.isEmpty) return;
    final scaledFontSize = fontSize * size.width / textReferenceWidth;

    final style = TextStyle(
      color: fontColor,
      fontSize: scaledFontSize,
      fontFamily: fontFamily,
    );

    final gridPaint = Paint()
      ..color = fontColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = scaledFontSize * 0.05;

    // Parse blocos (texto formatado vs tabela Markdown)
    final lines = parsedText.split('\n');
    final List<ContentBlock> blocks = [];

    List<MarkupParagraph> currentText = [];
    List<List<MarkupParagraph>> currentTable = [];

    for (final line in lines) {
      if (isTableLine(line)) {
        _addTextBlock(blocks, currentText);
        currentText = [];

        final trimmed = line.trim();
        final inner = trimmed.substring(1, trimmed.length - 1).trim();
        // Ignora separadores Markdown tipo |---|:---:|
        if (inner.replaceAll(RegExp(r'[\s\-:|]'), '').isEmpty) {
          continue;
        }

        currentTable.add(splitTableRow(inner).map(parseLine).toList());
      } else {
        if (currentTable.isNotEmpty) {
          blocks.add(TableBlock(currentTable));
          currentTable = [];
        }
        currentText.add(parseLine(line));
      }
    }

    _addTextBlock(blocks, currentText);
    if (currentTable.isNotEmpty) {
      blocks.add(TableBlock(currentTable));
    }

    // Layout
    double totalHeight = 0;
    List<Size> blockSizes = [];
    final double spacing = scaledFontSize;
    final maxWidth = size.width * 0.8;
    
    for (int i = 0; i < blocks.length; i++) {
      final s = blocks[i].layout(maxWidth, style);
      blockSizes.add(s);
      totalHeight += s.height;
      if (i < blocks.length - 1) totalHeight += spacing;
    }

    // Calcula âncora
    final anchorX = size.width * textPositionX;
    final anchorY = size.height * textPositionY;
    
    double startY = anchorY - totalHeight / 2;
    
    // Pintura
    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final bSize = blockSizes[i];
      
      final startX = anchorX - bSize.width / 2;
      block.paint(canvas, Offset(startX, startY), style, gridPaint);
      
      startY += bSize.height + spacing;
    }
  }

  static Future<Uint8List> generateCertificateImage(
    ui.Image templateImage,
    Map<String, dynamic> rowData,
    String textTemplate,
    double fontSize,
    String fontFamily,
    Color fontColor, {
    double textPositionX = 0.5,
    double textPositionY = 0.5,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final size = Size(templateImage.width.toDouble(), templateImage.height.toDouble());
    canvas.drawImage(templateImage, Offset.zero, Paint());

    // Substituir variáveis (valores escapados: o CSV não altera a formatação)
    final parsedText = fillTemplate(textTemplate, rowData);

    drawCertificateContent(
      canvas,
      size,
      parsedText,
      fontSize,
      fontFamily,
      fontColor,
      textPositionX: textPositionX,
      textPositionY: textPositionY,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }
}
