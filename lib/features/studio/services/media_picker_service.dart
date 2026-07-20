library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'camera_recorder_service.dart';

class MediaPickerService {
  const MediaPickerService();

  /// Opens the WeChat-style asset picker, supporting both photos and
  /// videos with multi-select, and resolves each [AssetEntity] down to a
  /// real file on disk + its real dimensions/duration.
  Future<List<CapturedMedia>> pickFromGallery(
    BuildContext context, {
    int maxAssets = 10,
    RequestType requestType = RequestType.common,
  }) async {
    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: maxAssets,
        requestType: requestType,
        sortPathDelegate: CommonSortPathDelegate.common,
      ),
    );

    if (assets == null || assets.isEmpty) return const [];

    final results = <CapturedMedia>[];
    for (final asset in assets) {
      final file = await asset.file;
      if (file == null) continue;
      results.add(
        CapturedMedia(
          filePath: file.path,
          isVideo: asset.type == AssetType.video,
          width: asset.width,
          height: asset.height,
          duration: Duration(seconds: asset.duration),
        ),
      );
    }
    return results;
  }

  /// `wechat_assets_picker`/`photo_manager` already do their own
  /// permission prompting through [pickFromGallery]; this is exposed for
  /// flows that need to check access *before* showing the picker UI
  /// (e.g. to show a custom "allow access" screen first).
  Future<bool> hasGalleryAccess() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.isAuth || state.hasAccess;
  }

  bool fileExists(String path) => File(path).existsSync();
}
