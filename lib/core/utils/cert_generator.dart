import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';

abstract class ContentBlock {
  Size layout(double maxWidth, TextStyle style);
  void paint(Canvas canvas, Offset offset, TextStyle style, Paint gridPaint);
}

class TextBlock extends ContentBlock {
  final String text;
  TextPainter? _painter;
  TextBlock(this.text);

  @override
  Size layout(double maxWidth, TextStyle style) {
    _painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    _painter!.layout(minWidth: 0, maxWidth: maxWidth);
    return _painter!.size;
  }

  @override
  void paint(Canvas canvas, Offset offset, TextStyle style, Paint gridPaint) {
    _painter!.paint(canvas, offset);
  }
}

class TableBlock extends ContentBlock {
  final List<List<String>> rows;
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
          text: TextSpan(text: rows[r][c], style: style),
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
        final text = rows[r][c];
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
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
    final style = TextStyle(
      color: fontColor,
      fontSize: fontSize,
      fontFamily: fontFamily,
    );

    final gridPaint = Paint()
      ..color = fontColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = fontSize * 0.05;

    // Parse blocos (texto normal vs tabela Markdown)
    final lines = parsedText.split('\n');
    List<ContentBlock> blocks = [];
    
    String currentText = '';
    List<List<String>> currentTable = [];
    
    for (String line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        if (currentText.isNotEmpty) {
          blocks.add(TextBlock(currentText.trimRight()));
          currentText = '';
        }
        
        final inner = trimmed.substring(1, trimmed.length - 1).trim();
        // Ignora separadores Markdown tipo |---|---|
        if (inner.replaceAll(RegExp(r'[\s\-]'), '').replaceAll('|', '').isEmpty) {
          continue;
        }
        
        final cells = inner.split('|').map((c) => c.trim()).toList();
        currentTable.add(cells);
      } else {
        if (currentTable.isNotEmpty) {
          blocks.add(TableBlock(currentTable));
          currentTable = [];
        }
        currentText += line + '\n';
      }
    }
    
    if (currentText.isNotEmpty) {
      blocks.add(TextBlock(currentText.trimRight()));
    }
    if (currentTable.isNotEmpty) {
      blocks.add(TableBlock(currentTable));
    }

    // Layout
    double totalHeight = 0;
    List<Size> blockSizes = [];
    final double spacing = fontSize; 
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

    // Substituir variáveis
    String parsedText = textTemplate;
    rowData.forEach((key, value) {
      parsedText = parsedText.replaceAll('{$key}', value.toString());
    });

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
