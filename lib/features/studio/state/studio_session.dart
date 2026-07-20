library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commands/history_engine.dart';
import '../commands/studio_command.dart';
import '../entities/layer.dart';
import '../entities/media_source.dart';
import '../entities/project.dart';
import '../entities/track.dart';
import '../utils/id_generator.dart';
import '../utils/typedefs.dart';

class StudioSessionState {
  final StudioProject project;
  final HistorySnapshot history;
  final Microseconds playhead;
  final StudioId? selectedLayerId;
  final bool isPlaying;
  final String? lastMessage;

  const StudioSessionState({
    required this.project,
    required this.history,
    required this.playhead,
    this.selectedLayerId,
    this.isPlaying = false,
    this.lastMessage,
  });

  factory StudioSessionState.initial() => StudioSessionState(
        project: StudioProject.create(id: IdGenerator.newProject()),
        history: HistorySnapshot.empty,
        playhead: 0,
      );

  StudioSessionState copyWith({
    StudioProject? project,
    HistorySnapshot? history,
    Microseconds? playhead,
    Object? selectedLayerId = _sentinel,
    bool? isPlaying,
    Object? lastMessage = _sentinel,
  }) {
    return StudioSessionState(
      project: project ?? this.project,
      history: history ?? this.history,
      playhead: playhead ?? this.playhead,
      selectedLayerId:
          identical(selectedLayerId, _sentinel) ? this.selectedLayerId : selectedLayerId as StudioId?,
      isPlaying: isPlaying ?? this.isPlaying,
      lastMessage: identical(lastMessage, _sentinel) ? this.lastMessage : lastMessage as String?,
    );
  }
}

const Object _sentinel = Object();

class StudioSessionNotifier extends Notifier<StudioSessionState> {
  late final HistoryEngine _history;

  @override
  StudioSessionState build() {
    _history = HistoryEngine();
    return StudioSessionState.initial();
  }

  void loadProject(StudioProject project) {
    _history.reset();
    state = StudioSessionState(project: project, history: _history.snapshot(), playhead: 0);
  }

  /// Seeds a fresh project with the tracks every Phase-1 post needs: one
  /// primary clip (video or photo), captions, and background music.
  /// Call this once right after the camera/gallery step hands back a
  /// source file.
  void seedFromCapturedClip({
    required String filePath,
    required String mimeType,
    required Microseconds duration,
    required int width,
    required int height,
  }) {
    final isVideo = mimeType.startsWith('video/');
    final sourceId = IdGenerator.newSource();
    final primaryTrackId = IdGenerator.newTrack();
    final textTrackId = IdGenerator.newTrack();
    final musicTrackId = IdGenerator.newTrack();

    var project = StudioProject.create(id: IdGenerator.newProject()).copyWith(
      tracks: [
        StudioTrack.create(
          id: primaryTrackId,
          kind: isVideo ? TrackKind.video : TrackKind.image,
          name: isVideo ? 'Video' : 'Photo',
        ),
        StudioTrack.create(id: textTrackId, kind: TrackKind.text, name: 'Text'),
        StudioTrack.create(id: IdGenerator.newTrack(), kind: TrackKind.sticker, name: 'Stickers'),
        StudioTrack.create(id: musicTrackId, kind: TrackKind.music, name: 'Music'),
      ],
    );

    final source = _mediaSource(sourceId, filePath, mimeType, duration, width, height);
    final layer = isVideo
        ? VideoLayer(
            id: IdGenerator.newLayer(),
            trackId: primaryTrackId,
            sourceId: sourceId,
            start: 0,
            duration: duration,
          )
        : ImageLayer(
            id: IdGenerator.newLayer(),
            trackId: primaryTrackId,
            sourceId: sourceId,
            start: 0,
            duration: duration,
          );

    project = project.copyWith(sources: [source], layers: [layer]);
    loadProject(project);
  }

  void execute(StudioCommand command) {
    final result = _history.apply(state.project, command);
    state = state.copyWith(
      project: result.project,
      history: _history.snapshot(),
      lastMessage: result.message,
    );
  }

  void undo() {
    final result = _history.undo(state.project);
    state = state.copyWith(project: result.project, history: _history.snapshot(), lastMessage: result.message);
  }

  void redo() {
    final result = _history.redo(state.project);
    state = state.copyWith(project: result.project, history: _history.snapshot(), lastMessage: result.message);
  }

  void selectLayer(StudioId? id) => state = state.copyWith(selectedLayerId: id);

  void setPlayhead(Microseconds t) {
    final clamped = t.clamp(0, state.project.totalDuration == 0 ? 1 : state.project.totalDuration);
    state = state.copyWith(playhead: clamped);
  }

  void setPlaying(bool playing) => state = state.copyWith(isPlaying: playing);

  void setCaption(String caption) => state = state.copyWith(
        project: state.project.copyWith(caption: caption, updatedAt: DateTime.now()),
      );

  void setCaptionWithDetections(String caption, {List<String> hashtags = const [], List<String> mentions = const []}) {
    state = state.copyWith(
      project: state.project.copyWith(
        caption: caption,
        hashtags: hashtags,
        mentions: mentions,
        updatedAt: DateTime.now(),
      ),
    );
  }
}

MediaSource _mediaSource(
  String id,
  String path,
  String mimeType,
  Microseconds duration,
  int width,
  int height,
) {
  return MediaSource(
    id: id,
    path: path,
    mimeType: mimeType,
    duration: duration,
    width: width,
    height: height,
    createdAt: DateTime.now(),
  );
}

final studioSessionProvider = NotifierProvider<StudioSessionNotifier, StudioSessionState>(
  StudioSessionNotifier.new,
);
