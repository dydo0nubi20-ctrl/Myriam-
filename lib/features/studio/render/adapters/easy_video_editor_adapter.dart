library;

import 'dart:async';

import 'package:easy_video_editor/easy_video_editor.dart';

import '../../entities/layer.dart';
import '../render_pipeline.dart';

/// Trim-only export path. `easy_video_editor` runs entirely on native
/// platform APIs (`MediaCodec`/`AVFoundation`) — no FFmpeg binary, no GPL
/// concerns, much smaller app size than the alternative. It's picked
/// whenever [isPlainTrimOnly] says the project has no overlays or filter,
/// which covers the large majority of quick posts.
class EasyVideoEditorAdapter implements RenderAdapter {
  @override
  String get id => 'easy_video_editor';

  @override
  bool supports(project) => isPlainTrimOnly(project);

  @override
  Stream<RenderProgress> render(RenderJob job, CancellationToken token) {
    final controller = StreamController<RenderProgress>();
    unawaited(_run(job, token, controller));
    return controller.stream;
  }

  Future<void> _run(RenderJob job, CancellationToken token, StreamController<RenderProgress> controller) async {
    final videoLayer = job.project.layers.whereType<VideoLayer>().first;
    final source = job.project.sourceById(videoLayer.sourceId);
    if (source == null) {
      controller.add(const RenderProgress(fraction: 0, stage: RenderStage.failed, message: 'Video source not found'));
      await controller.close();
      return;
    }

    controller.add(const RenderProgress(fraction: 0, stage: RenderStage.queued));

    final startMs = videoLayer.sourceStart ~/ 1000;
    final endMs = startMs + (videoLayer.duration ~/ 1000);

    var builder = VideoEditorBuilder(videoPath: source.path).trim(startTimeMs: startMs, endTimeMs: endMs);
    if (videoLayer.speed != 1.0) {
      builder = builder.speed(speed: videoLayer.speed);
    }
    if (videoLayer.volume == 0) {
      builder = builder.removeAudio();
    }

    try {
      final outputPath = await builder.export(
        outputPath: job.outputPath,
        onProgress: (progress) {
          if (token.isCancelled) return;
          controller.add(RenderProgress(fraction: progress, stage: RenderStage.rendering));
        },
      );

      if (token.isCancelled) {
        controller.add(const RenderProgress(fraction: 0, stage: RenderStage.cancelled, message: 'Cancelled'));
      } else {
        controller.add(RenderProgress(fraction: 1, stage: RenderStage.done, message: outputPath));
      }
    } catch (e) {
      controller.add(RenderProgress(fraction: 0, stage: RenderStage.failed, message: e.toString()));
    } finally {
      await controller.close();
    }
  }
}
