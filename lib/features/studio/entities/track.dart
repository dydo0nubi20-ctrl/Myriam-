library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/typedefs.dart';

part 'track.freezed.dart';
part 'track.g.dart';

enum TrackKind { video, image, text, sticker, music, voiceover }

extension TrackKindX on TrackKind {
  /// Default stacking order — higher z paints on top.
  int get defaultZ => switch (this) {
        TrackKind.video => 0,
        TrackKind.image => 10,
        TrackKind.sticker => 20,
        TrackKind.text => 30,
        TrackKind.music => 40,
        TrackKind.voiceover => 41,
      };

  bool get isAudio => this == TrackKind.music || this == TrackKind.voiceover;
}

@freezed
class StudioTrack with _$StudioTrack {
  const factory StudioTrack({
    required StudioId id,
    required TrackKind kind,
    @Default('Track') String name,
    @Default(true) bool enabled,
    @Default(1.0) double volume,
    required int z,
  }) = _StudioTrack;

  factory StudioTrack.fromJson(Map<String, dynamic> json) =>
      _$StudioTrackFromJson(json);

  factory StudioTrack.create({
    required StudioId id,
    required TrackKind kind,
    String? name,
  }) =>
      StudioTrack(
        id: id,
        kind: kind,
        name: name ?? kind.name,
        z: kind.defaultZ,
      );
}
