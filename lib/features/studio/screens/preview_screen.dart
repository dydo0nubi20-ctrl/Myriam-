library;

import 'dart:io';

import 'package:detectable_text_field/detector/sample_regular_expressions.dart';
import 'package:detectable_text_field/widgets/detectable_text_editing_controller.dart';
import 'package:detectable_text_field/widgets/detectable_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../state/studio_session.dart';
import '../theme/studio_colors.dart';
import '../widgets/preview_canvas.dart';
import '../widgets/studio_button.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key});

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  VideoPlayerController? _videoController;
  late final DetectableTextEditingController _captionController;

  @override
  void initState() {
    super.initState();
    final project = ref.read(studioSessionProvider).project;
    _captionController = DetectableTextEditingController(regExp: detectionRegExp())
      ..text = project.caption;

    final videoLayer = project.primaryVideoLayer;
    if (videoLayer != null) {
      final source = project.sourceById(videoLayer.sourceId);
      if (source != null) {
        _videoController = VideoPlayerController.file(File(source.path))
          ..initialize().then((_) {
            if (mounted) setState(() {});
            _videoController!.setLooping(true);
            _videoController!.play();
            ref.read(studioSessionProvider.notifier).setPlaying(true);
          });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    final controller = _videoController;
    if (controller == null) return;
    final notifier = ref.read(studioSessionProvider.notifier);
    if (controller.value.isPlaying) {
      controller.pause();
      notifier.setPlaying(false);
    } else {
      controller.play();
      notifier.setPlaying(true);
    }
    setState(() {});
  }

  void _onCaptionChanged(String text) {
    final hashtags = extractDetections(text, hashTagRegExp);
    final mentions = extractDetections(text, atSignRegExp);
    ref.read(studioSessionProvider.notifier).setCaptionWithDetections(
          text,
          hashtags: hashtags,
          mentions: mentions,
        );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(studioSessionProvider);
    final isPlaying = _videoController?.value.isPlaying ?? false;

    return Scaffold(
      backgroundColor: StudioColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.md, vertical: StudioSpacing.sm),
              child: Row(
                children: [
                  StudioButton(
                    label: '',
                    icon: Icons.arrow_back_ios_new,
                    variant: StudioButtonVariant.secondary,
                    compact: true,
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  const Text('Preview', style: TextStyle(color: StudioColors.textPrimary, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: _togglePlayback,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PreviewCanvas(
                      project: session.project,
                      playhead: session.playhead,
                      videoController: _videoController,
                    ),
                    if (!isPlaying)
                      const Icon(Icons.play_arrow, color: Colors.white, size: 64),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(StudioSpacing.lg),
              child: DetectableTextField(
                controller: _captionController,
                detectionRegExp: detectionRegExp(),
                maxLines: 3,
                style: const TextStyle(color: StudioColors.textPrimary, fontSize: 14),
                basicStyle: const TextStyle(color: StudioColors.textPrimary, fontSize: 14),
                detectedStyle: const TextStyle(color: StudioColors.accent, fontSize: 14, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'Write a caption… use #hashtags and @mentions',
                  hintStyle: TextStyle(color: StudioColors.textTertiary),
                  filled: true,
                  fillColor: StudioColors.surfaceRaised,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(StudioRadius.md)), borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.all(StudioSpacing.md),
                ),
                onChanged: _onCaptionChanged,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                StudioSpacing.lg,
                0,
                StudioSpacing.lg,
                StudioSpacing.lg,
              ),
              child: StudioButton(
                label: 'Share to feed',
                icon: Icons.send_rounded,
                fullWidth: true,
                onPressed: () => context.push('/studio/export'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
