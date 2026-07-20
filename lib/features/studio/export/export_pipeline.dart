library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import '../entities/layer.dart';
import '../entities/project.dart';
import '../render/render_pipeline.dart';
import '../utils/id_generator.dart';
import 'export_settings.dart';

class ExportOutcome {
  final String outputPath;
  final bool isVideo;
  const ExportOutcome({required this.outputPath, required this.isVideo});
}

/// Single entry point the export screen calls. Branches on whether the
/// project's primary layer is a video or a photo — videos go through
/// [RenderPipeline] (easy_video_editor / pro_video_editor), photos are
/// composited directly here with `dart:ui` since there is no video
/// renderer involved at all for a still image.
class ExportPipeline {
  ExportPipeline({required RenderPipeline renderPipeline}) : _renderPipeline = renderPipeline;

  final RenderPipeline _renderPipeline;

  Stream<RenderProgress> exportVideo(StudioProject project, ExportSettings settings) async* {
    final dir = await getTemporaryDirectory();
    final outputPath = '${dir.path}/setrize_export_${IdGenerator.newExport()}.mp4';
    final job = RenderJob(id: IdGenerator.newExport(), project: project, outputPath: outputPath);
    yield* _renderPipeline.render(job);
  }

  /// Composites every active text layer onto the source photo using a
  /// real offscreen `dart:ui` canvas (no third-party image-editor
  /// package needed for this) and writes a flattened PNG to disk.
  Future<String> exportPhoto(StudioProject project) async {
    final imageLayer = project.layers.whereType<ImageLayer>().first;
    final source = project.sourceById(imageLayer.sourceId);
    if (source == null) throw StateError('Photo source not found');

    final bytes = await File(source.path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final baseImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImage(baseImage, ui.Offset.zero, ui.Paint());

    for (final layer in project.layers) {
      if (layer is TextLayer) {
        _drawText(canvas, layer, baseImage.width, baseImage.height);
      } else if (layer is StickerLayer) {
        _drawSticker(canvas, layer, baseImage.width, baseImage.height);
      }
    }

    final picture = recorder.endRecording();
    final composited = await picture.toImage(baseImage.width, baseImage.height);
    final pngBytes = await composited.toByteData(format: ui.ImageByteFormat.png);
    composited.dispose();
    picture.dispose();
    baseImage.dispose();

    if (pngBytes == null) throw StateError('Failed to flatten photo export');

    final dir = await getTemporaryDirectory();
    final outputPath = '${dir.path}/setrize_export_${IdGenerator.newExport()}.png';
    await File(outputPath).writeAsBytes(pngBytes.buffer.asUint8List());
    return outputPath;
  }

  void _drawText(ui.Canvas canvas, TextLayer layer, int width, int height) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: ui.TextAlign.center, fontSize: layer.preset.fontSize),
    )
      ..pushStyle(ui.TextStyle(
        foreground: ui.Paint()..color = layer.preset.color,
        fontWeight: layer.preset.fontWeight,
        fontSize: layer.preset.fontSize,
      ))
      ..addText(layer.text);
    final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: width * 0.86));
    final dx = layer.transform.dx * width - paragraph.width / 2;
    final dy = layer.transform.dy * height - paragraph.height / 2;
    canvas.drawParagraph(paragraph, ui.Offset(dx, dy));
  }

  void _drawSticker(ui.Canvas canvas, StickerLayer layer, int width, int height) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 64 * layer.transform.scale))
      ..addText(layer.payload);
    final paragraph = builder.build()..layout(const ui.ParagraphConstraints(width: 200));
    final dx = layer.transform.dx * width - paragraph.width / 2;
    final dy = layer.transform.dy * height - paragraph.height / 2;
    canvas.drawParagraph(paragraph, ui.Offset(dx, dy));
  }
}
