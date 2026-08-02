library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' show Offset;
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

import '../../entities/layer.dart';
import '../../entities/project.dart';
import '../../utils/typedefs.dart';
import '../filter_registry.dart';
import '../layer_rasterizer.dart';
import '../render_pipeline.dart';

class ProVideoEditorAdapter implements RenderAdapter {
  const ProVideoEditorAdapter({LayerRasterizer? rasterizer})
      : _rasterizer = rasterizer ?? const LayerRasterizer();

  final LayerRasterizer _rasterizer;

  @override
  String get id => 'pro_video_editor';

  @override
  bool supports(StudioProject project) =>
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
          fraction: 0, stage: RenderStage.cancelled, message: 'Cancelled'));
      await controller.close();
      return;
    }

    final filter = FilterRegistry.byId(videoLayer.colorFilterId);
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

    final progressSub = pve.ProVideoEditor.instance
        .progressStreamById(job.id)
        .listen((p) {
      if (token.isCancelled) return;
      controller.add(RenderProgress(
        fraction: p.progress.clamp(0.0, 1.0),
        stage: RenderStage.rendering,
      ));
    });

    try {
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
      await progressSub.cancel();
      await controller.close();
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
