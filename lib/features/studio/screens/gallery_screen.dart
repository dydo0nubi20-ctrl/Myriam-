library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../services/media_picker_service.dart';
import '../theme/studio_colors.dart';
import '../widgets/studio_button.dart';

/// Entry point reached from the feed's "Import" action. It immediately
/// opens the real WeChat-style picker (multi-select photos + videos);
/// once the user confirms a single asset we hand it straight to the
/// editor. Multi-asset stitching is a Phase-2 concern — for now, picking
/// more than one asset just opens the editor with the first one and
/// tells the user the rest are ignored, instead of silently dropping
/// them with no feedback.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _picker = const MediaPickerService();
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPicker());
  }

  Future<void> _openPicker() async {
    if (_opening) return;
    setState(() => _opening = true);

    final hasAccess = await _picker.hasGalleryAccess();
    if (!hasAccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo library access is required to import media.')),
        );
        context.pop();
      }
      return;
    }

    final results = await _picker.pickFromGallery(
      context,
      maxAssets: 10,
      requestType: RequestType.common,
    );

    if (!mounted) return;

    if (results.isEmpty) {
      context.pop();
      return;
    }

    if (results.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the first item will be edited for now.')),
      );
    }

    final media = results.first;
    context.pushReplacement('/studio/editor', extra: {
      'path': media.filePath,
      'isVideo': media.isVideo,
      'width': media.width,
      'height': media.height,
      'durationMicros': media.duration.inMicroseconds,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudioColors.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: StudioSpacing.lg),
            const Text('Opening your library…', style: TextStyle(color: StudioColors.textSecondary)),
            const SizedBox(height: StudioSpacing.xl),
            StudioButton(
              label: 'Cancel',
              variant: StudioButtonVariant.secondary,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}
