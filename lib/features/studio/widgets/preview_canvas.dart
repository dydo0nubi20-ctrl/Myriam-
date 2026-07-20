library;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../entities/project.dart';
import '../theme/studio_colors.dart';
import '../utils/typedefs.dart';
import 'layer_overlays.dart';

/// Renders the actual frame the user will get on export: the real video
/// (via [VideoPlayerController]) plus every text/sticker layer that's
/// active at [playhead]. Overlay rendering is delegated to
/// [layerOverlayWidgets] — the same function the editor screen uses — so
/// what you see while editing is what gets exported.
class PreviewCanvas extends StatelessWidget {
  const PreviewCanvas({
    super.key,
    required this.project,
    required this.playhead,
    this.videoController,
  });

  final StudioProject project;
  final Microseconds playhead;
  final VideoPlayerController? videoController;

  @override
  Widget build(BuildContext context) {
    final ratio = project.aspectRatio.ratio;
    final screen = MediaQuery.of(context).size;
    final maxHeight = screen.height * 0.62;
    var height = maxHeight;
    var width = height * ratio;
    if (width > screen.width - StudioSpacing.lg * 2) {
      width = screen.width - StudioSpacing.lg * 2;
      height = width / ratio;
    }

    final activeLayers = project.layers.where((l) => l.isVisual && l.isActiveAt(playhead)).toList()
      ..sort((a, b) {
        final za = project.trackById(a.trackRef)?.z ?? 0;
        final zb = project.trackById(b.trackRef)?.z ?? 0;
        return za.compareTo(zb);
      });

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(StudioRadius.lg),
        child: Container(
          width: width,
          height: height,
          color: StudioColors.canvas,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildVideoLayer(),
              ...layerOverlayWidgets(activeLayers),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoLayer() {
    final controller = videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Icon(Icons.movie_outlined, color: StudioColors.textTertiary, size: 48),
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}
