import 'package:flutter_test/flutter_test.dart';

import 'package:setrize/features/studio/engine/timeline_engine.dart';
import 'package:setrize/features/studio/entities/layer.dart';
import 'package:setrize/features/studio/entities/project.dart';
import 'package:setrize/features/studio/entities/track.dart';
import 'package:setrize/features/studio/entities/transform.dart';
import 'package:setrize/features/studio/utils/typedefs.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

StudioProject _project({List<StudioTrack>? tracks, List<StudioLayer>? layers}) {
  return StudioProject.create(id: 'p1').copyWith(
    tracks: tracks ?? [StudioTrack.create(id: 't1', kind: TrackKind.text)],
    layers: layers ?? const [],
  );
}

TextLayer _text(String id, {Microseconds start = 0, Microseconds duration = 3000000}) =>
    TextLayer(
      id: id,
      trackId: 't1',
      text: 'hi',
      start: start,
      duration: duration,
      transform: StudioTransform.identity,
    );

VideoLayer _video(String id, {Microseconds start = 0, Microseconds duration = 5000000}) =>
    VideoLayer(
      id: id,
      trackId: 'tv',
      sourceId: 'src',
      start: start,
      duration: duration,
    );

// ── tests ─────────────────────────────────────────────────────────────────────

void main() {
  final engine = TimelineEngine(snapEnabled: false);

  group('TimelineEngine.activeLayersAt', () {
    test('returns layer when playhead is within its range', () {
      final layer = _text('l1', start: 1000000, duration: 2000000);
      final project = _project(layers: [layer]);

      expect(engine.activeLayersAt(project, 1500000), contains(layer));
    });

    test('returns empty list before the layer starts', () {
      final layer = _text('l1', start: 2000000, duration: 3000000);
      final project = _project(layers: [layer]);

      expect(engine.activeLayersAt(project, 0), isEmpty);
    });

    test('returns empty list at or after the layer ends', () {
      final layer = _text('l1', start: 0, duration: 2000000);
      final project = _project(layers: [layer]);

      // endAt == 2 000 000; isActiveAt checks t < endAt
      expect(engine.activeLayersAt(project, 2000000), isEmpty);
    });

    test('sorts by track z-order when multiple tracks overlap', () {
      final videoTrack = StudioTrack.create(id: 'tv', kind: TrackKind.video); // z=0
      final textTrack = StudioTrack.create(id: 'tt', kind: TrackKind.text);   // z=30
      final v = _video('v1');
      final t = _text('t1');

      final project = StudioProject.create(id: 'p1').copyWith(
        tracks: [videoTrack, textTrack],
        layers: [t, v],
      );

      final active = engine.activeLayersAt(project, 1000000);
      expect(active.first.layerId, 'v1'); // video track has lower z
      expect(active.last.layerId, 't1');
    });
  });

  group('TimelineEngine.snap (enabled)', () {
    final snapping = TimelineEngine(snapEnabled: true, snapThresholdMicros: 100000);

    test('snaps to playhead when within threshold', () {
      final project = _project();
      final result = snapping.snap(project, candidate: 50000, playhead: 0);
      expect(result.time, 0);
      expect(result.target, SnapTarget.playhead);
    });

    test('snaps to clip start when within threshold', () {
      final layer = _text('l1', start: 1000000);
      final project = _project(layers: [layer]);
      final result = snapping.snap(project, candidate: 1050000);
      expect(result.time, 1000000);
      expect(result.target, SnapTarget.clipStart);
    });

    test('does not snap when candidate is outside threshold of all points', () {
      final project = _project();
      final result = snapping.snap(project, candidate: 5000000, playhead: 0);
      expect(result.target, SnapTarget.none);
      expect(result.time, 5000000);
    });

    test('ignores the layer being dragged', () {
      final layer = _text('l1', start: 1000000);
      final project = _project(layers: [layer]);
      final result = snapping.snap(project,
          candidate: 1050000, ignoreLayerId: 'l1');
      // The only snap candidate left is 0 (origin); 1050000 is too far.
      expect(result.target, SnapTarget.none);
    });
  });

  group('TimelineEngine.findFreeSlot', () {
    test('returns 0 for an empty track', () {
      final project = _project();
      expect(engine.findFreeSlot(project, trackId: 't1', duration: 3000000), 0);
    });

    test('places the new clip after an existing one', () {
      final layer = _text('l1', start: 0, duration: 3000000);
      final project = _project(layers: [layer]);
      expect(
        engine.findFreeSlot(project, trackId: 't1', duration: 2000000),
        3000000,
      );
    });

    test('finds a gap between two clips if one is large enough', () {
      final a = _text('a', start: 0, duration: 2000000);
      final b = _text('b', start: 5000000, duration: 2000000);
      final project = _project(layers: [a, b]);
      // Gap from 2 000 000 to 5 000 000 (3 s) fits a 2 s clip.
      expect(
        engine.findFreeSlot(project, trackId: 't1', duration: 2000000),
        2000000,
      );
    });
  });

  group('TimelineEngine.clampStart', () {
    test('clamps below 0 to 0', () {
      final project = _project(layers: [_text('l', start: 0, duration: 5000000)]);
      expect(engine.clampStart(project, -1000000, 2000000), 0);
    });

    test('does not exceed total duration minus clip duration', () {
      final project = _project(layers: [_text('l', start: 0, duration: 10000000)]);
      // totalDuration = 10 s; clip is 6 s → max start = 4 s
      expect(engine.clampStart(project, 9000000, 6000000), 4000000);
    });

    test('passes through valid values unchanged', () {
      final project = _project(layers: [_text('l', start: 0, duration: 10000000)]);
      expect(engine.clampStart(project, 2000000, 3000000), 2000000);
    });
  });

  group('TimelineEngine.suggestedTrackKind', () {
    test('VideoLayer → video track', () {
      expect(engine.suggestedTrackKind(_video('v')), TrackKind.video);
    });

    test('TextLayer → text track', () {
      expect(engine.suggestedTrackKind(_text('t')), TrackKind.text);
    });

    test('AudioLayer → music track', () {
      final audio = AudioLayer(
        id: 'a',
        trackId: 'tm',
        sourceId: 'src',
        start: 0,
        duration: 5000000,
      );
      expect(engine.suggestedTrackKind(audio), TrackKind.music);
    });
  });
}
