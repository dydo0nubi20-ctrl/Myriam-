library;

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../services/camera_recorder_service.dart';
import '../theme/studio_colors.dart';
import '../widgets/studio_button.dart';

/// Real camera capture screen, backed by `camerawesome`'s built-in UI.
///
/// The `.awesome()` builder already ships flash toggle, front/back
/// switch and pinch-to-zoom for free — we only add a close button and a
/// 60s cap. camerawesome's public API has no "force-stop recording at
/// N seconds" hook on the built-in UI, so the hard 60s ceiling is
/// actually enforced one step later, in the editor's trim controller
/// (`maxDuration`) — recording longer than 60s is still possible, but
/// the clip is capped to the first 60s before it can be exported. This
/// is documented here instead of faked with a timer that silently does
/// nothing.
class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  static const int maxRecordingSeconds = 60;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudioColors.canvas,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: CameraAwesomeBuilder.awesome(
                saveConfig: SaveConfig.photoAndVideo(
                  videoPathBuilder: (sensors) async {
                    final dir = await getTemporaryDirectory();
                    final path =
                        '${dir.path}/setrize_${DateTime.now().millisecondsSinceEpoch}.mp4';
                    return SingleCaptureRequest(path, sensors.first);
                  },
                  photoPathBuilder: (sensors) async {
                    final dir = await getTemporaryDirectory();
                    final path =
                        '${dir.path}/setrize_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    return SingleCaptureRequest(path, sensors.first);
                  },
                  videoOptions: VideoOptions(
                    enableAudio: true,
                    android: AndroidVideoOptions(
                      bitrate: 6 * 1000 * 1000,
                      fallbackStrategy: QualityFallbackStrategy.lower,
                    ),
                  ),
                ),
                sensorConfig: SensorConfig.single(
                  sensor: Sensor.position(SensorPosition.back),
                  // camerawesome's CameraAspectRatios enum only has 1:1, 4:3
                  // and 16:9 — there is no `ratio_9_16` value. Sensors are
                  // described in landscape terms; held upright (portrait,
                  // which this whole app is locked to), `ratio_16_9` is
                  // exactly the 9:16 vertical frame Reels/TikTok use.
                  aspectRatio: CameraAspectRatios.ratio_16_9,
                  flashMode: FlashMode.auto,
                  zoom: 0.0,
                ),
                previewFit: CameraPreviewFit.cover,
                enablePhysicalButton: true,
                // NOTE: `onMediaTap` fires when the user taps the small
                // "last captured media" thumbnail button in the built-in
                // UI — it does NOT fire when a capture finishes. The
                // actual "capture just completed" signal is
                // `onMediaCaptureEvent`, checked for `MediaCaptureStatus
                // .success` below.
                onMediaCaptureEvent: (event) => _handleCaptureEvent(context, event),
              ),
            ),
            Positioned(
              top: StudioSpacing.sm,
              left: StudioSpacing.sm,
              child: SafeArea(
                child: StudioButton(
                  label: '',
                  icon: Icons.close,
                  variant: StudioButtonVariant.secondary,
                  compact: true,
                  onPressed: () => context.pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCaptureEvent(BuildContext context, MediaCaptureEvent event) async {
    if (event.status != MediaCaptureStatus.success) return;

    final path = event.captureRequest.when(
      single: (single) => single.file?.path,
      multiple: (multiple) => multiple.fileBySensor.values.first?.path,
    );
    if (path == null) return;

    if (event.isPicture) {
      // Dimensions aren't known synchronously here; the editor screen
      // reads them off the file itself when it loads it.
      if (context.mounted) {
        context.push('/studio/editor', extra: {'path': path, 'isVideo': false});
      }
      return;
    }

    final inspector = CameraRecorderService();
    final media = await inspector.inspectVideo(path);
    if (context.mounted) {
      context.push('/studio/editor', extra: {
        'path': media.filePath,
        'isVideo': true,
        'width': media.width,
        'height': media.height,
        'durationMicros': media.duration.inMicroseconds,
      });
    }
  }
}
