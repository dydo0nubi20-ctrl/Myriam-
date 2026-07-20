library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' show Offset;
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

import '../../entities/layer.dart';
import '../../utils/typedefs.dart';
import '../filter_registry.dart';
import '../layer_rasterizer.dart';
import '../render_pipeline.dart';

/// Full compositor path: trims the clip, bakes in the chosen color
/// filter via `colorFilters`, and overlays every text/sticker layer as a
/// rasterized PNG `pve.ImageLayer`. Picked whenever [isPlainTrimOnly] is
/// false, i.e. whenever there's anything `easy_video_editor` alone can't
/// express.
///
/// NAMING NOTE — `pro_video_editor` exports its own `ImageLayer` class;
/// our Freezed entity also has a subtype called `ImageLayer`. Both are
/// in this file, so `pro_video_editor` is imported with the `pve`
/// prefix to avoid an ambiguity compile error.
class ProVideoEditorAdapter implements RenderAdapter {
  const ProVideoEditorAdapter({LayerRasterizer? rasterizer})
      : _rasterizer = rasterizer ?? const LayerRasterizer();

  final LayerRasterizer _rasterizer;

  @override
  String get id => 'pro_video_editor';

  @override
  bool supports(project) =>
      project.layers.whereType<VideoLayer>().length == 1;

  @override
  Stream<RenderProgress> render(RenderJob job, CancellationToken token) {
    final controller = StreamController<RenderProgress>();
    unawaited(_run(job, token, controller));
    return controller.stream;
  }

  Future<void> _run(
    RenderJob job,
    CancellationToken token,
    StreamController<RenderProgress> controller,
  ) async {
    final project = job.project;
    final videoLayer = project.layers.whereType<VideoLayer>().firstOrNull;
    if (videoLayer == null) {
      controller.add(const RenderProgress(
          fraction: 0, stage: RenderStage.failed, message: 'No video layer'));
      await controller.close();
      return;
    }
    final source = project.sourceById(videoLayer.sourceId);
    if (source == null) {
      controller.add(const RenderProgress(
          fraction: 0,
          stage: RenderStage.failed,
          message: 'Video source not found'));
      await controller.close();
      return;
    }

    controller.add(
        const RenderProgress(fraction: 0, stage: RenderStage.queued));

    final canvasWidth = source.width > 0 ? source.width : 1080;
    final canvasHeight = source.height > 0 ? source.height : 1920;

    // Rasterize every text/sticker layer to a full-canvas transparent PNG
    // then hand it to pro_video_editor as a pve.ImageLayer (the package's
    // own overlay type — different from our Freezed ImageLayer entity).
    final pveImageLayers = <pve.ImageLayer>[];
    for (final layer in project.layers) {
      if (token.isCancelled) break;
      if (layer is TextLayer) {
        final bytes =
            await _rasterizer.rasterizeText(layer, canvasWidth, canvasHeight);
        pveImageLayers.add(pve.ImageLayer(
          imageBytes: bytes,
          offset: Offset.zero,
          startTime: layer.startAt.asDuration,
          endTime: layer.endAt.asDuration,
        ));
      } else if (layer is StickerLayer) {
        final bytes = await _rasterizer.rasterizeSticker(
            layer, canvasWidth, canvasHeight);
        pveImageLayers.add(pve.ImageLayer(
          imageBytes: bytes,
          offset: Offset.zero,
          startTime: layer.startAt.asDuration,
          endTime: layer.endAt.asDuration,
        ));
      }
    }

    if (token.isCancelled) {
      controller.add(const RenderProgress(
          fraction: 0,
          stage: RenderStage.cancelled,
          message: 'Cancelled'));
      await controller.close();
      return;
    }

    final filter = FilterRegistry.byId(videoLayer.colorFilterId);
    // pro_video_editor's docs confirm logStream (native logs) but don't
    // expose a render-progress stream for renderVideoToFile. Progress is
    // reported in honest coarse stages rather than a fabricated percentage.
    controller.add(const RenderProgress(
        fraction: 0.1,
        stage: RenderStage.rendering,
        message: 'Compositing layers'));

    try {
      final renderData = pve.VideoRenderData(
        id: job.id,
        videoSegments: [
          pve.VideoSegment(
            video: pve.EditorVideo.file(File(source.path)),
            volume: videoLayer.volume,
          ),
        ],
        imageLayers: pveImageLayers,
        startTime: videoLayer.sourceStart.asDuration,
        endTime: (videoLayer.sourceStart + videoLayer.duration).asDuration,
        playbackSpeed: videoLayer.speed,
        outputFormat: pve.VideoOutputFormat.mp4,
        enableAudio: videoLayer.volume > 0,
        colorFilters: filter.id == FilterRegistry.none.id
            ? const []
            : [pve.ColorFilter(matrix: filter.matrix)],
      );

      await pve.ProVideoEditor.instance
          .renderVideoToFile(job.outputPath, renderData);

      if (token.isCancelled) {
        controller.add(const RenderProgress(
            fraction: 0, stage: RenderStage.cancelled, message: 'Cancelled'));
      } else {
        controller.add(RenderProgress(
            fraction: 1, stage: RenderStage.done, message: job.outputPath));
      }
    } on pve.RenderCanceledException {
      controller.add(const RenderProgress(
          fraction: 0, stage: RenderStage.cancelled, message: 'Cancelled'));
    } catch (e) {
      controller.add(RenderProgress(
          fraction: 0, stage: RenderStage.failed, message: e.toString()));
    } finally {
      await controller.close();
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}


/// Full compositor path: trims the clip, bakes in the chosen color
/// filter via `colorFilters` (a real `VideoRenderData` field — verified
/// against the package's own README, not assumed), and overlays every
/// text/sticker layer as a rasterized PNG `ImageLayer`. Picked whenever
/// [isPlainTrimOnly] is false, i.e. whenever there's anything
/// `easy_video_editor` alone can't express.
class ProVideoEditorAdapter implements RenderAdapter {
  const ProVideoEditorAdapter({LayerRasterizer? rasterizer}) : _rasterizer = rasterizer ?? const LayerRasterizer();

  final LayerRasterizer _rasterizer;

  @override
  String get id => 'pro_video_editor';

  @override
  bool supports(project) => project.layers.whereType<VideoLayer>().length == 1;

  @override
  Stream<RenderProgress> render(RenderJob job, CancellationToken token) {
    final controller = StreamController<RenderProgress>();
    unawaited(_run(job, token, controller));
    return controller.stream;
  }

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
