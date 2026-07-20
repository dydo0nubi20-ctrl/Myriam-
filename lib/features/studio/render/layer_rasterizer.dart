library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import '../entities/layer.dart';

/// `pro_video_editor`'s `ImageLayer` takes a flat PNG (`imageBytes`) plus a
/// *pixel* `offset` — it has no concept of "draw this text here". So
/// every text/sticker layer gets rasterized, once, to a transparent PNG
/// the exact size of the export canvas, with the glyph already painted
/// at the right spot inside it. The layer's pixel offset is then always
/// `Offset.zero` — all the positioning math happens once, here, instead
/// of being duplicated between the live preview and the export path.
class LayerRasterizer {
  const LayerRasterizer();

  Future<Uint8List> rasterizeText(TextLayer layer, int canvasWidth, int canvasHeight) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()));

    final painter = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: _toUiTextAlign(layer.preset.align),
        fontWeight: layer.preset.fontWeight,
        fontSize: layer.preset.fontSize,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: layer.preset.color,
        fontWeight: layer.preset.fontWeight,
        fontSize: layer.preset.fontSize,
        foreground: ui.Paint()
          ..color = layer.preset.color
          ..style = ui.PaintingStyle.fill,
      ))
      ..addText(layer.text);

    final paragraph = painter.build()
      ..layout(ui.ParagraphConstraints(width: canvasWidth * 0.86));

    // Stroke pass first (drawn slightly offset in 8 directions) gives a
    // cheap outline effect without needing a second compositing layer.
    final strokeBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: _toUiTextAlign(layer.preset.align),
        fontWeight: layer.preset.fontWeight,
        fontSize: layer.preset.fontSize,
      ),
    )
      ..pushStyle(ui.TextStyle(
        fontWeight: layer.preset.fontWeight,
        fontSize: layer.preset.fontSize,
        foreground: ui.Paint()
          ..color = layer.preset.strokeColor
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = layer.preset.strokeWidth,
      ))
      ..addText(layer.text);
    final strokeParagraph = strokeBuilder.build()
      ..layout(ui.ParagraphConstraints(width: canvasWidth * 0.86));

    final dx = layer.transform.dx * canvasWidth - paragraph.width / 2;
    final dy = layer.transform.dy * canvasHeight - paragraph.height / 2;

    canvas.drawParagraph(strokeParagraph, ui.Offset(dx, dy));
    canvas.drawParagraph(paragraph, ui.Offset(dx, dy));

    return _finish(recorder, canvasWidth, canvasHeight);
  }

  Future<Uint8List> rasterizeSticker(StickerLayer layer, int canvasWidth, int canvasHeight) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()));

    final fontSize = 64.0 * layer.transform.scale;
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: fontSize))
      ..addText(layer.payload);
    final paragraph = builder.build()..layout(const ui.ParagraphConstraints(width: 200));

    final dx = layer.transform.dx * canvasWidth - paragraph.width / 2;
    final dy = layer.transform.dy * canvasHeight - paragraph.height / 2;
    canvas.drawParagraph(paragraph, ui.Offset(dx, dy));

    return _finish(recorder, canvasWidth, canvasHeight);
  }

  Future<Uint8List> _finish(ui.PictureRecorder recorder, int width, int height) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (bytes == null) {
      throw StateError('Failed to encode rasterized layer to PNG');
    }
    return bytes.buffer.asUint8List();
  }

  ui.TextAlign _toUiTextAlign(dynamic flutterTextAlign) {
    // `layer.preset.align` is a Flutter `material.TextAlign`; `dart:ui`
    // has its own `TextAlign` with identical enum names, so we map by
    // name rather than importing `package:flutter/material.dart` here
    // (this file intentionally has zero Flutter widget dependencies —
    // it should be usable from a background isolate later if export
    // ever needs to move off the UI thread).
    final name = flutterTextAlign.toString().split('.').last;
    return ui.TextAlign.values.firstWhere((a) => a.name == name, orElse: () => ui.TextAlign.center);
  }
}
