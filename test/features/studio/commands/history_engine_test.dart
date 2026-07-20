import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show Offset;

import 'package:setrize/features/studio/commands/editing_commands.dart';
import 'package:setrize/features/studio/commands/history_engine.dart';
import 'package:setrize/features/studio/entities/layer.dart';
import 'package:setrize/features/studio/entities/project.dart';
import 'package:setrize/features/studio/entities/track.dart';
import 'package:setrize/features/studio/entities/transform.dart';
import 'package:setrize/features/studio/utils/typedefs.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

StudioProject _emptyProject() =>
    StudioProject.create(id: 'p1').copyWith(
      tracks: [StudioTrack.create(id: 't1', kind: TrackKind.text, name: 'Text')],
    );

TextLayer _textLayer(String id, {Microseconds start = 0, Microseconds duration = 3000000}) =>
    TextLayer(
      id: id,
      trackId: 't1',
      text: 'Hello',
      start: start,
      duration: duration,
      transform: StudioTransform.identity,
    );

// ── tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('HistoryEngine', () {
    test('apply adds to undo stack and success is true', () {
      final engine = HistoryEngine();
      final project = _emptyProject();
      final result = engine.apply(project, AddLayerCommand(layer: _textLayer('l1')));

      expect(result.success, isTrue);
      expect(result.project.layers.length, 1);
      expect(engine.snapshot().canUndo, isTrue);
      expect(engine.snapshot().canRedo, isFalse);
    });

    test('undo restores previous state and moves command to redo stack', () {
      final engine = HistoryEngine();
      var project = _emptyProject();
      project = engine.apply(project, AddLayerCommand(layer: _textLayer('l1'))).project;

      final undone = engine.undo(project);
      expect(undone.success, isTrue);
      expect(undone.project.layers, isEmpty);
      expect(engine.snapshot().canUndo, isFalse);
      expect(engine.snapshot().canRedo, isTrue);
    });

    test('redo re-applies the undone command', () {
      final engine = HistoryEngine();
      var project = _emptyProject();
      project = engine.apply(project, AddLayerCommand(layer: _textLayer('l1'))).project;
      project = engine.undo(project).project;
      final redone = engine.redo(project);

      expect(redone.success, isTrue);
      expect(redone.project.layers.length, 1);
      expect(engine.snapshot().canUndo, isTrue);
      expect(engine.snapshot().canRedo, isFalse);
    });

    test('new command clears the redo stack', () {
      final engine = HistoryEngine();
      var project = _emptyProject();
      project = engine.apply(project, AddLayerCommand(layer: _textLayer('l1'))).project;
      project = engine.undo(project).project;

      // Apply a new command — redo stack must be cleared.
      project = engine.apply(project, AddLayerCommand(layer: _textLayer('l2'))).project;
      expect(engine.snapshot().canRedo, isFalse);
    });

    test('mergeable commands collapse into a single undo entry', () {
      final engine = HistoryEngine();
      var project = _emptyProject();
      project = engine.apply(project, AddLayerCommand(layer: _textLayer('l1'))).project;
      expect(engine.snapshot().undoCount, 1);

      // Three consecutive MoveLayerCommands (isMergeable == true) should
      // leave exactly 2 undo entries (AddLayer + the last Move), not 4.
      for (var i = 1; i <= 3; i++) {
        project = engine
            .apply(project, MoveLayerCommand(layerId: 'l1', newStart: i * 1000000))
            .project;
      }
      expect(engine.snapshot().undoCount, 2);
    });

    test('undo on empty stack returns failure without changing project', () {
      final engine = HistoryEngine();
      final project = _emptyProject();
      final result = engine.undo(project);
      expect(result.success, isFalse);
      expect(result.project.layers, isEmpty);
    });

    test('redo on empty stack returns failure without changing project', () {
      final engine = HistoryEngine();
      final project = _emptyProject();
      final result = engine.redo(project);
      expect(result.success, isFalse);
    });

    test('maxSize cap evicts oldest entry when exceeded', () {
      final engine = HistoryEngine(maxSize: 3);
      var project = _emptyProject();

      for (var i = 0; i < 5; i++) {
        project =
            engine.apply(project, AddLayerCommand(layer: _textLayer('l$i'))).project;
      }
      expect(engine.snapshot().undoCount, 3);
    });

    test('reset clears both stacks', () {
      final engine = HistoryEngine();
      var project = _emptyProject();
      project = engine.apply(project, AddLayerCommand(layer: _textLayer('l1'))).project;
      engine.undo(project);
      engine.reset();

      expect(engine.snapshot().canUndo, isFalse);
      expect(engine.snapshot().canRedo, isFalse);
    });
  });

  group('SplitClipCommand', () {
    test('split produces two layers whose durations sum to the original', () {
      var project = _emptyProject();
      final original = _textLayer('l1', duration: 10000000);
      project = AddLayerCommand(layer: original).execute(project).project;

      final cmd = SplitClipCommand(layerId: 'l1', atMicroseconds: 4000000);
      project = cmd.execute(project).project;

      expect(project.layers.length, 2);
      final total = project.layers.fold<int>(0, (sum, l) => sum + l.durationMicros);
      expect(total, original.durationMicros);
    });

    test('split then undo restores the single original layer', () {
      var project = _emptyProject();
      project = AddLayerCommand(layer: _textLayer('l1', duration: 10000000))
          .execute(project)
          .project;

      final cmd = SplitClipCommand(layerId: 'l1', atMicroseconds: 6000000);
      project = cmd.execute(project).project;
      expect(project.layers.length, 2);

      project = cmd.undo(project).project;
      expect(project.layers.length, 1);
      expect(project.layers.first.layerId, 'l1');
      expect(project.layers.first.durationMicros, 10000000);
    });

    test('split outside clip bounds returns failure', () {
      var project = _emptyProject();
      project = AddLayerCommand(layer: _textLayer('l1', duration: 5000000))
          .execute(project)
          .project;

      final result = SplitClipCommand(layerId: 'l1', atMicroseconds: 0).execute(project);
      expect(result, isA<CommandFailure>());
      expect(result.project.layers.length, 1); // project unchanged
    });
  });

  group('DeleteLayerCommand', () {
    test('delete removes layer; undo restores it', () {
      var project = _emptyProject();
      project = AddLayerCommand(layer: _textLayer('l1')).execute(project).project;

      final cmd = DeleteLayerCommand(layerId: 'l1');
      project = cmd.execute(project).project;
      expect(project.layers, isEmpty);

      project = cmd.undo(project).project;
      expect(project.layers.length, 1);
      expect(project.layers.first.layerId, 'l1');
    });

    test('deleting a non-existent layer returns failure', () {
      final project = _emptyProject();
      final result = DeleteLayerCommand(layerId: 'ghost').execute(project);
      expect(result, isA<CommandFailure>());
    });
  });

  group('TrimClipCommand', () {
    test('trim updates start and duration; undo reverts them', () {
      var project = _emptyProject();
      project = AddLayerCommand(layer: _textLayer('l1', start: 0, duration: 10000000))
          .execute(project)
          .project;

      final cmd = TrimClipCommand(
        layerId: 'l1',
        newStart: 1000000,
        newDuration: 6000000,
        newSourceStart: 1000000,
      );
      project = cmd.execute(project).project;
      expect(project.layers.first.startAt, 1000000);
      expect(project.layers.first.durationMicros, 6000000);

      project = cmd.undo(project).project;
      expect(project.layers.first.startAt, 0);
      expect(project.layers.first.durationMicros, 10000000);
    });
  });

  group('SetColorFilterCommand', () {
    test('filter id is updated; undo reverts it', () {
      var project = StudioProject.create(id: 'p1').copyWith(
        tracks: [StudioTrack.create(id: 'tv', kind: TrackKind.video, name: 'V')],
        layers: [
          VideoLayer(
            id: 'v1',
            trackId: 'tv',
            sourceId: 's1',
            start: 0,
            duration: 5000000,
          ),
        ],
      );

      final cmd = SetColorFilterCommand(layerId: 'v1', filterId: 'sepia');
      project = cmd.execute(project).project;
      expect((project.layers.first as VideoLayer).colorFilterId, 'sepia');

      project = cmd.undo(project).project;
      expect((project.layers.first as VideoLayer).colorFilterId, 'none');
    });
  });
}
