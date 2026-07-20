library;

import '../entities/layer.dart';
import '../entities/project.dart';

enum RenderStage { queued, rendering, done, failed, cancelled }

class RenderProgress {
  final double fraction;
  final RenderStage stage;
  final String? message;
  const RenderProgress({required this.fraction, required this.stage, this.message});
}

class CancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class RenderJob {
  final String id;
  final StudioProject project;
  final String outputPath;
  const RenderJob({required this.id, required this.project, required this.outputPath});
}

abstract interface class RenderAdapter {
  String get id;

  /// Whether this adapter can fully render [project] on its own. Adapters
  /// are checked in registration order — the cheapest/lightest adapter
  /// that can do the job wins, so a plain trim never pays the cost of
  /// the full multi-layer compositor.
  bool supports(StudioProject project);

  Stream<RenderProgress> render(RenderJob job, CancellationToken token);
}

/// Picks an adapter and exposes a single progress stream regardless of
/// which adapter actually ends up doing the work — callers (the export
/// screen) never need to know whether a clip was simple enough for
/// `easy_video_editor` or needed the full `pro_video_editor` compositor.
class RenderPipeline {
  RenderPipeline({required List<RenderAdapter> adapters}) : _adapters = adapters;

  final List<RenderAdapter> _adapters;

  RenderAdapter? pickAdapter(StudioProject project) {
    for (final adapter in _adapters) {
      if (adapter.supports(project)) return adapter;
    }
    return null;
  }

  Stream<RenderProgress> render(RenderJob job, {CancellationToken? token}) {
    final adapter = pickAdapter(job.project);
    if (adapter == null) {
      return Stream.value(
        const RenderProgress(fraction: 0, stage: RenderStage.failed, message: 'No adapter supports this project'),
      );
    }
    return adapter.render(job, token ?? CancellationToken());
  }
}

/// True only when the project is a single video clip with no text,
/// stickers, or color filter — the case `easy_video_editor` (trim-only,
/// no FFmpeg) can fully handle on its own.
bool isPlainTrimOnly(StudioProject project) {
  final hasOverlay = project.layers.any((l) => l is TextLayer || l is StickerLayer);
  final videoLayers = project.layers.whereType<VideoLayer>().toList();
  if (videoLayers.length != 1) return false;
  final hasFilter = videoLayers.first.colorFilterId != 'none';
  final hasAudioLayer = project.layers.any((l) => l is AudioLayer);
  return !hasOverlay && !hasFilter && !hasAudioLayer;
}
