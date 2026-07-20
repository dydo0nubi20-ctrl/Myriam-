library;

import '../entities/layer.dart';
import '../entities/project.dart';
import '../entities/track.dart';
import '../utils/typedefs.dart';

enum SnapTarget { none, playhead, clipStart, clipEnd }

class SnapResult {
  final Microseconds time;
  final SnapTarget target;
  const SnapResult(this.time, this.target);
}

/// Pure, stateless timeline math: nothing here touches Flutter widgets or
/// platform channels, so it's trivially unit-testable (see
/// `test/features/studio/engine/timeline_engine_test.dart`).
class TimelineEngine {
  TimelineEngine({this.snapEnabled = true, this.snapThresholdMicros = 120000});

  final bool snapEnabled;
  final Microseconds snapThresholdMicros;

  List<StudioLayer> activeLayersAt(StudioProject project, Microseconds t) {
    final layers = project.layers.where((l) => l.isActiveAt(t)).toList();
    layers.sort((a, b) {
      final za = project.trackById(a.trackRef)?.z ?? 0;
      final zb = project.trackById(b.trackRef)?.z ?? 0;
      return za.compareTo(zb);
    });
    return layers;
  }

  SnapResult snap(
    StudioProject project, {
    required Microseconds candidate,
    Microseconds? playhead,
    StudioId? ignoreLayerId,
  }) {
    if (!snapEnabled) return SnapResult(candidate, SnapTarget.none);

    final points = <(Microseconds, SnapTarget)>[];
    if (playhead != null) points.add((playhead, SnapTarget.playhead));
    points.add((0, SnapTarget.clipStart));
    for (final l in project.layers) {
      if (l.layerId == ignoreLayerId) continue;
      points.add((l.startAt, SnapTarget.clipStart));
      points.add((l.endAt, SnapTarget.clipEnd));
    }

    var best = candidate;
    var bestTarget = SnapTarget.none;
    var bestDelta = snapThresholdMicros;

    for (final (p, target) in points) {
      final delta = (candidate - p).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = p;
        bestTarget = target;
      }
    }
    return SnapResult(best, bestTarget);
  }

  /// First free starting point on [trackId] that can fit [duration]
  /// without overlapping an existing layer.
  Microseconds findFreeSlot(
    StudioProject project, {
    required StudioId trackId,
    required Microseconds duration,
    Microseconds earliestStart = 0,
  }) {
    final onTrack = project.layersOnTrack(trackId)
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    var cursor = earliestStart;
    for (final layer in onTrack) {
      if (layer.endAt <= cursor) continue;
      if (layer.startAt >= cursor + duration) return cursor;
      cursor = layer.endAt;
    }
    return cursor;
  }

  TrackKind suggestedTrackKind(StudioLayer layer) => layer.map(
        video: (_) => TrackKind.video,
        image: (_) => TrackKind.image,
        text: (_) => TrackKind.text,
        sticker: (_) => TrackKind.sticker,
        audio: (_) => TrackKind.music,
      );

  Microseconds clampStart(StudioProject project, Microseconds candidate, Microseconds duration) {
    if (candidate < 0) return 0;
    final maxStart = project.totalDuration - duration;
    if (maxStart <= 0) return 0;
    return candidate > maxStart ? maxStart : candidate;
  }
}
