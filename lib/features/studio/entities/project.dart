library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/typedefs.dart';
import 'layer.dart';
import 'media_source.dart';
import 'track.dart';

part 'project.freezed.dart';
part 'project.g.dart';

enum AspectRatioPreset {
  vertical9x16(9, 16),
  square1x1(1, 1),
  horizontal16x9(16, 9);

  final int w;
  final int h;
  const AspectRatioPreset(this.w, this.h);

  double get ratio => w / h;
}

enum ProjectStage { draft, editing, exporting, uploading, published, failed }

@freezed
class StudioProject with _$StudioProject {
  const StudioProject._();

  const factory StudioProject({
    required StudioId id,
    @Default('') String caption,
    @Default(AspectRatioPreset.vertical9x16) AspectRatioPreset aspectRatio,
    @Default(<StudioTrack>[]) List<StudioTrack> tracks,
    @Default(<StudioLayer>[]) List<StudioLayer> layers,
    @Default(<MediaSource>[]) List<MediaSource> sources,
    @Default(<String>[]) List<String> hashtags,
    @Default(<String>[]) List<String> mentions,
    Microseconds? explicitDuration,
    @Default(ProjectStage.draft) ProjectStage stage,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? coverPath,
  }) = _StudioProject;

  factory StudioProject.fromJson(Map<String, dynamic> json) =>
      _$StudioProjectFromJson(json);

  factory StudioProject.create({required StudioId id}) {
    final now = DateTime.now();
    return StudioProject(id: id, createdAt: now, updatedAt: now);
  }

  Microseconds get totalDuration =>
      explicitDuration ??
      layers.fold<Microseconds>(0, (max, l) {
        return l.endAt > max ? l.endAt : max;
      });

  List<StudioTrack> get sortedTracks =>
      [...tracks]..sort((a, b) => a.z.compareTo(b.z));

  List<StudioLayer> layersOnTrack(StudioId trackId) =>
      layers.where((l) => l.trackRef == trackId).toList();

  StudioLayer? layerById(StudioId id) => layers
      .where((l) => l.layerId == id)
      .cast<StudioLayer?>()
      .firstWhere((_) => true, orElse: () => null);

  StudioTrack? trackById(StudioId id) => tracks
      .where((t) => t.id == id)
      .cast<StudioTrack?>()
      .firstWhere((_) => true, orElse: () => null);

  MediaSource? sourceById(StudioId id) => sources
      .where((s) => s.id == id)
      .cast<MediaSource?>()
      .firstWhere((_) => true, orElse: () => null);

  /// The single primary video layer the camera/gallery flow produces in
  /// the MVP. Multi-clip stitching is a Phase-2 concern.
  VideoLayer? get primaryVideoLayer {
    for (final l in layers) {
      if (l is VideoLayer) return l;
    }
    return null;
  }
}
