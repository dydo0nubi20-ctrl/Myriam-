library;

import 'package:uuid/uuid.dart';

import '../entities/layer.dart';
import '../entities/media_source.dart';
import '../entities/project.dart';
import '../entities/track.dart';
import '../entities/transform.dart';
import '../utils/typedefs.dart';
import 'studio_command.dart';

// ───────────────────────────── Tracks ─────────────────────────────

class AddTrackCommand implements StudioCommand {
  AddTrackCommand({required this.track}) : commandId = 'add_track_${track.id}';

  final StudioTrack track;
  @override
  final String commandId;
  @override
  String get label => 'Add ${track.kind.name} track';

  @override
  CommandResult execute(StudioProject project) {
    if (project.tracks.any((t) => t.id == track.id)) {
      return CommandFailure(project, StateError('Track already exists'));
    }
    return CommandSuccess(project.copyWith(tracks: [...project.tracks, track]), label);
  }

  @override
  CommandResult undo(StudioProject project) {
    return CommandSuccess(
      project.copyWith(tracks: project.tracks.where((t) => t.id != track.id).toList()),
      'Undo: $label',
    );
  }
}

// ───────────────────────────── Layers ─────────────────────────────

class AddLayerCommand implements StudioCommand {
  AddLayerCommand({required this.layer, this.source, String? commandId})
      : commandId = commandId ?? 'add_layer_${layer.layerId}';

  final StudioLayer layer;
  final MediaSource? source;
  @override
  final String commandId;
  @override
  String get label => 'Add ${layer.runtimeType}';

  @override
  CommandResult execute(StudioProject project) {
    final sources = (source == null || project.sources.any((s) => s.id == source!.id))
        ? project.sources
        : [...project.sources, source!];
    return CommandSuccess(
      project.copyWith(layers: [...project.layers, layer], sources: sources),
      label,
    );
  }

  @override
  CommandResult undo(StudioProject project) {
    return CommandSuccess(
      project.copyWith(layers: project.layers.where((l) => l.layerId != layer.layerId).toList()),
      'Undo: $label',
    );
  }
}

class DeleteLayerCommand implements StudioCommand {
  DeleteLayerCommand({required this.layerId}) : commandId = 'delete_layer_$layerId';

  final StudioId layerId;
  @override
  final String commandId;
  @override
  String get label => 'Delete layer';

  StudioLayer? _removed;

  @override
  CommandResult execute(StudioProject project) {
    final layer = project.layerById(layerId);
    if (layer == null) return CommandFailure(project, StateError('Layer not found'));
    _removed = layer;
    return CommandSuccess(
      project.copyWith(layers: project.layers.where((l) => l.layerId != layerId).toList()),
      label,
    );
  }

  @override
  CommandResult undo(StudioProject project) {
    final removed = _removed;
    if (removed == null) return CommandSuccess(project);
    return CommandSuccess(project.copyWith(layers: [...project.layers, removed]), 'Undo: $label');
  }
}

class MoveLayerCommand implements StudioCommand {
  MoveLayerCommand({required this.layerId, required this.newStart})
      : commandId = 'move_layer_$layerId';

  final StudioId layerId;
  final Microseconds newStart;
  @override
  final String commandId;
  @override
  bool get isMergeable => true;
  @override
  String get label => 'Move layer';

  Microseconds? _oldStart;

  @override
  CommandResult execute(StudioProject project) {
    final idx = project.layers.indexWhere((l) => l.layerId == layerId);
    if (idx == -1) return CommandFailure(project, StateError('Layer not found'));
    _oldStart = project.layers[idx].startAt;
    final updated = _withStart(project.layers[idx], newStart);
    return CommandSuccess(
      project.copyWith(layers: [...project.layers]..[idx] = updated),
      label,
    );
  }

  @override
  CommandResult undo(StudioProject project) {
    final idx = project.layers.indexWhere((l) => l.layerId == layerId);
    if (idx == -1 || _oldStart == null) return CommandSuccess(project);
    final restored = _withStart(project.layers[idx], _oldStart!);
    return CommandSuccess(project.copyWith(layers: [...project.layers]..[idx] = restored), 'Undo: $label');
  }
}

class TrimClipCommand implements StudioCommand {
  TrimClipCommand({
    required this.layerId,
    required this.newStart,
    required this.newDuration,
    this.newSourceStart,
  }) : commandId = 'trim_layer_$layerId';

  final StudioId layerId;
  final Microseconds newStart;
  final Microseconds newDuration;
  final Microseconds? newSourceStart;
  @override
  final String commandId;
  @override
  bool get isMergeable => true;
  @override
  String get label => 'Trim clip';

  Microseconds? _oldStart;
  Microseconds? _oldDuration;
  Microseconds? _oldSourceStart;

  @override
  CommandResult execute(StudioProject project) {
    final idx = project.layers.indexWhere((l) => l.layerId == layerId);
    if (idx == -1) return CommandFailure(project, StateError('Layer not found'));
    final old = project.layers[idx];
    _oldStart = old.startAt;
    _oldDuration = old.durationMicros;
    _oldSourceStart = old is VideoLayer
        ? old.sourceStart
        : old is AudioLayer
            ? old.sourceStart
            : 0;

    final updated = _withTrim(old, newStart, newDuration, newSourceStart ?? _oldSourceStart);
    return CommandSuccess(project.copyWith(layers: [...project.layers]..[idx] = updated), label);
  }

  @override
  CommandResult undo(StudioProject project) {
    final idx = project.layers.indexWhere((l) => l.layerId == layerId);
    if (idx == -1) return CommandSuccess(project);
    final restored = _withTrim(
      project.layers[idx],
      _oldStart ?? project.layers[idx].startAt,
      _oldDuration ?? project.layers[idx].durationMicros,
      _oldSourceStart ?? 0,
    );
    return CommandSuccess(project.copyWith(layers: [...project.layers]..[idx] = restored), 'Undo: $label');
  }
}

class SplitClipCommand implements StudioCommand {
  SplitClipCommand({required this.layerId, required this.atMicroseconds})
      : commandId = 'split_${const Uuid().v4()}';

  final StudioId layerId;
  final Microseconds atMicroseconds;
  @override
  final String commandId;
  @override
  String get label => 'Split clip';

  StudioLayer? _insertedSecondHalf;

  @override
  CommandResult execute(StudioProject project) {
    final idx = project.layers.indexWhere((l) => l.layerId == layerId);
    if (idx == -1) return CommandFailure(project, StateError('Layer not found'));
    final original = project.layers[idx];
    final cut = atMicroseconds - original.startAt;
    if (cut <= 0 || cut >= original.durationMicros) {
      return CommandFailure(project, RangeError('Split point out of range'));
    }

    final firstDuration = cut;
    final secondDuration = original.durationMicros - cut;
    final secondStart = original.startAt + firstDuration;
    final sourceStart = original is VideoLayer
        ? original.sourceStart
        : original is AudioLayer
            ? original.sourceStart
            : 0;

    final first = _withTrim(original, original.startAt, firstDuration, sourceStart);
    final secondId = '${original.layerId}_b_${const Uuid().v4().substring(0, 6)}';
    final second = _withTrim(
      _withId(original, secondId),
      secondStart,
      secondDuration,
      sourceStart + firstDuration,
    );

    _insertedSecondHalf = second;
    final layers = [...project.layers]..[idx] = first;
    layers.insert(idx + 1, second);
    return CommandSuccess(project.copyWith(layers: layers), label);
  }

  @override
  CommandResult undo(StudioProject project) {
    final secondId = _insertedSecondHalf?.layerId;
    if (secondId == null) return CommandSuccess(project);
    final idx = project.layers.indexWhere((l) => l.layerId == layerId);
    if (idx == -1) return CommandSuccess(project);
    final first = project.layers[idx];
    final mergedDuration = first.durationMicros + _insertedSecondHalf!.durationMicros;
    final sourceStart = first is VideoLayer
        ? first.sourceStart
        : first is AudioLayer
            ? first.sourceStart
            : 0;
    final restored = _withTrim(first, first.startAt, mergedDuration, sourceStart);
    final layers = [...project.layers]
      ..[idx] = restored
      ..removeWhere((l) => l.layerId == secondId);
    return CommandSuccess(project.copyWith(layers: layers), 'Undo: $label');
  }
}

class UpdateTransformCommand implements StudioCommand {
  UpdateTransformCommand({required this.layerId, required this.newTransform})
      : commandId = 'transform_$layerId';

  final StudioId layerId;
  final StudioTransform newTransform;
  @override
  final String commandId;
  @override
  bool get isMergeable => true;
  @override
  String get label => 'Move / resize';

  StudioTransform? _old;

  @override
  CommandResult execute(StudioProject project) {
    final idx = project.layers.indexWhere((l) => l.layerId == layerId);
    if (idx == -1) return CommandFailure(project, StateError('Layer not found'));
    _old = _transformOf(project.layers[idx]);
    final updated = _withTransform(project.layers[idx], newTransform);
    return CommandSuccess(project.copyWith(layers: [...project.layers]..[idx] = updated), label);
  }

  @override
  CommandResult undo(StudioProject project) {
    final idx = project.layers.indexWhere((l) => l.layerId == layerId);
    if (idx == -1 || _old == null) return CommandSuccess(project);
    final restored = _withTransform(project.layers[idx], _old!);
    return CommandSuccess(project.copyWith(layers: [...project.layers]..[idx] = restored), 'Undo: $label');
  }
}

class SetColorFilterCommand implements StudioCommand {
  SetColorFilterCommand({required this.layerId, required this.filterId})
      : commandId = 'color_filter_$layerId';

  final StudioId layerId;
  final String filterId;
  @override
  final String commandId;
  @override
  String get label => 'Apply filter';

  String? _old;

  @override
  CommandResult execute(StudioProject project) {
    final idx = project.layers.indexWhere((l) => l.layerId == layerId);
    if (idx == -1) return CommandFailure(project, StateError('Layer not found'));
    final layer = project.layers[idx];
    if (layer is! VideoLayer) {
      return CommandFailure(project, StateError('Color filters only apply to video layers'));
    }
    _old = layer.colorFilterId;
    final updated = layer.copyWith(colorFilterId: filterId);
    return CommandSuccess(project.copyWith(layers: [...project.layers]..[idx] = updated), label);
  }

  @override
  CommandResult undo(StudioProject project) {
    final idx = project.layers.indexWhere((l) => l.layerId == layerId);
    if (idx == -1 || _old == null) return CommandSuccess(project);
    final layer = project.layers[idx];
    if (layer is! VideoLayer) return CommandSuccess(project);
    final restored = layer.copyWith(colorFilterId: _old!);
    return CommandSuccess(project.copyWith(layers: [...project.layers]..[idx] = restored), 'Undo: $label');
  }
}

class SetCaptionCommand implements StudioCommand {
  SetCaptionCommand({required this.newCaption}) : commandId = 'set_caption';

  final String newCaption;
  @override
  final String commandId;
  @override
  bool get isMergeable => true;
  @override
  String get label => 'Edit caption';

  String? _old;

  @override
  CommandResult execute(StudioProject project) {
    _old = project.caption;
    return CommandSuccess(project.copyWith(caption: newCaption), label);
  }

  @override
  CommandResult undo(StudioProject project) {
    return CommandSuccess(project.copyWith(caption: _old ?? ''), 'Undo: $label');
  }
}

// ───────────────────────────── helpers ─────────────────────────────

StudioLayer _withId(StudioLayer layer, StudioId id) => layer.map(
      video: (l) => l.copyWith(id: id),
      image: (l) => l.copyWith(id: id),
      text: (l) => l.copyWith(id: id),
      sticker: (l) => l.copyWith(id: id),
      audio: (l) => l.copyWith(id: id),
    );

StudioLayer _withStart(StudioLayer layer, Microseconds start) => layer.map(
      video: (l) => l.copyWith(start: start),
      image: (l) => l.copyWith(start: start),
      text: (l) => l.copyWith(start: start),
      sticker: (l) => l.copyWith(start: start),
      audio: (l) => l.copyWith(start: start),
    );

StudioLayer _withTrim(
  StudioLayer layer,
  Microseconds start,
  Microseconds duration,
  Microseconds sourceStart,
) =>
    layer.map(
      video: (l) => l.copyWith(start: start, duration: duration, sourceStart: sourceStart),
      image: (l) => l.copyWith(start: start, duration: duration),
      text: (l) => l.copyWith(start: start, duration: duration),
      sticker: (l) => l.copyWith(start: start, duration: duration),
      audio: (l) => l.copyWith(start: start, duration: duration, sourceStart: sourceStart),
    );

StudioTransform _transformOf(StudioLayer layer) => layer.map(
      video: (l) => l.transform,
      image: (l) => l.transform,
      text: (l) => l.transform,
      sticker: (l) => l.transform,
      audio: (_) => StudioTransform.identity,
    );

StudioLayer _withTransform(StudioLayer layer, StudioTransform transform) => layer.map(
      video: (l) => l.copyWith(transform: transform),
      image: (l) => l.copyWith(transform: transform),
      text: (l) => l.copyWith(transform: transform),
      sticker: (l) => l.copyWith(transform: transform),
      audio: (l) => l,
    );
