library;

import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'camera_recorder_service.dart';

/// Opens the phone's own native gallery/photo picker — the same system
/// UI every other app on the device uses (Instagram, WhatsApp, etc.) —
/// instead of a custom in-app picker. On Android 13+ this is backed by
/// the system Photo Picker, which needs *no storage permission at all*
/// since the OS runs it out-of-process and only hands the app the
/// files the user actually picked.
class MediaPickerService {
  MediaPickerService() : _picker = ImagePicker();

  final ImagePicker _picker;

  /// Opens the system picker for images + videos together, with
  /// multi-select. Returns an empty list if the user cancels.
  Future<List<CapturedMedia>> pickFromGallery() async {
    final files = await _picker.pickMultipleMedia();
    if (files.isEmpty) return const [];

    final results = <CapturedMedia>[];
    for (final file in files) {
      final isVideo = _looksLikeVideo(file.path);
      if (isVideo) {
        final inspected = await CameraRecorderService().inspectVideo(file.path);
        results.add(inspected);
      } else {
        final inspected = await CameraRecorderService().inspectPhoto(file.path);
        results.add(inspected);
      }
    }
    return results;
  }

  bool _looksLikeVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.3gp');
  }

  bool fileExists(String path) => File(path).existsSync();
}
