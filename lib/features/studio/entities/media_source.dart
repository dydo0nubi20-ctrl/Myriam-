library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/typedefs.dart';

part 'media_source.freezed.dart';
part 'media_source.g.dart';

/// A piece of physical media (file on disk) referenced by one or more
/// layers. Kept separate from [StudioLayer] so the same source (e.g. a
/// music track) can be reused by several layers without duplicating
/// file metadata.
@freezed
class MediaSource with _$MediaSource {
  const MediaSource._();

  const factory MediaSource({
    required StudioId id,
    required String path,
    required String mimeType,
    required Microseconds duration,
    @Default(0) int width,
    @Default(0) int height,
    @Default(0) int rotationDegrees,
    @Default(0) int sizeBytes,
    String? thumbnailPath,
    DateTime? createdAt,
  }) = _MediaSource;

  factory MediaSource.fromJson(Map<String, dynamic> json) =>
      _$MediaSourceFromJson(json);

  bool get isVideo => mimeType.startsWith('video/');
  bool get isImage => mimeType.startsWith('image/');
  bool get isAudio => mimeType.startsWith('audio/');

  (int, int) get dimensions => (width, height);
}
