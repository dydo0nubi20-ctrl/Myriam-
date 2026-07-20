library;

import 'dart:io';

import 'package:video_player/video_player.dart';

/// Thin wrapper around whatever `camerawesome` hands back from a capture,
/// normalised into the fields the rest of the studio actually needs
/// (camerawesome's `MediaCapture` object differs slightly between photo
/// and video captures, so we resolve everything to a flat result here
/// instead of leaning on camerawesome types past the camera screen).
class CapturedMedia {
  final String filePath;
  final bool isVideo;
  final int width;
  final int height;
  final Duration duration;

  const CapturedMedia({
    required this.filePath,
    required this.isVideo,
    required this.width,
    required this.height,
    required this.duration,
  });
}

class CameraRecorderService {
  CameraRecorderService();

  /// Reads real width/height/duration off a freshly captured video file
  /// using `video_player` (no platform channel beyond what video_player
  /// already opens), so downstream layers always carry accurate metadata
  /// instead of guessed constants.
  Future<CapturedMedia> inspectVideo(String path) async {
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      final size = controller.value.size;
      return CapturedMedia(
        filePath: path,
        isVideo: true,
        width: size.width.round(),
        height: size.height.round(),
        duration: controller.value.duration,
      );
    } finally {
      await controller.dispose();
    }
  }

  CapturedMedia inspectPhoto(String path, {required int width, required int height}) {
    return CapturedMedia(
      filePath: path,
      isVideo: false,
      width: width,
      height: height,
      duration: Duration.zero,
    );
  }
}
