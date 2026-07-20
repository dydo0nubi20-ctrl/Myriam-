library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_editor_2/video_editor.dart';

import '../commands/editing_commands.dart';
import '../entities/layer.dart';
import '../entities/track.dart';
import '../entities/transform.dart';
import '../render/filter_registry.dart';
import '../services/camera_recorder_service.dart';
import '../state/studio_session.dart';
import '../theme/studio_colors.dart';
import '../utils/typedefs.dart';
import '../widgets/layer_overlays.dart';
import '../widgets/studio_button.dart';
import '../widgets/tool_bar.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({
    super.key,
    required this.path,
    required this.isVideo,
    this.width = 0,
    this.height = 0,
    this.durationMicros = 0,
  });

  final String path;
  final bool isVideo;
  final int width;
  final int height;
  final Microseconds durationMicros;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  VideoEditorController? _videoController;
  bool _ready = false;
  String _activeFilterId = FilterRegistry.none.id;
  String? _primaryVideoLayerId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    int width = widget.width;
    int height = widget.height;
    Microseconds durationMicros = widget.durationMicros;

    if (widget.isVideo) {
      // If we got here from the gallery rather than the camera screen,
      // the caller may not have inspected the file yet.
      if (durationMicros == 0 || width == 0) {
        final inspected = await CameraRecorderService().inspectVideo(widget.path);
        width = inspected.width;
        height = inspected.height;
        durationMicros = inspected.duration.inMicroseconds;
      }

      final cappedSeconds = (durationMicros / 1000000).ceil().clamp(1, 60);
      _videoController = VideoEditorController.file(
        File(widget.path),
        minDuration: const Duration(seconds: 1),
        maxDuration: Duration(seconds: cappedSeconds),
      );
      await _videoController!.initialize();
    }

    if (!mounted) return;

    final notifier = ref.read(studioSessionProvider.notifier);
    notifier.seedFromCapturedClip(
      filePath: widget.path,
      mimeType: widget.isVideo ? 'video/mp4' : 'image/jpeg',
      duration: widget.isVideo ? durationMicros : fromSeconds(5),
      width: width,
      height: height,
    );

    final layer = ref.read(studioSessionProvider).project.primaryVideoLayer;
    setState(() {
      _primaryVideoLayerId = layer?.layerId;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: StudioColors.canvas,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final session = ref.watch(studioSessionProvider);
    final notifier = ref.read(studioSessionProvider.notifier);
    final activeLayers =
        session.project.layers.where((l) => l.isVisual && l is! VideoLayer).toList();

    return Scaffold(
      backgroundColor: StudioColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context, session),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(child: _videoOrImagePreview()),
                  ...layerOverlayWidgets(activeLayers),
                ],
              ),
            ),
            if (widget.isVideo) _trimAndCover(),
            _filterStrip(),
            ToolBar(
              hasSelection: session.selectedLayerId != null,
              canUndo: session.history.canUndo,
              canRedo: session.history.canRedo,
              onUndo: notifier.undo,
              onRedo: notifier.redo,
              onAddText: _addText,
              onAddSticker: _addSticker,
              onAddMusic: _addMusicPlaceholderNotice,
              onFilters: () {},
              onSplit: () {},
              onDelete: _deleteSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoOrImagePreview() {
    final filter = FilterRegistry.byId(_activeFilterId);
    final colorMatrix = ColorFilter.matrix(filter.matrix);

    if (widget.isVideo && _videoController != null) {
      return ColorFiltered(
        colorFilter: colorMatrix,
        child: CropGridViewer.preview(controller: _videoController!),
      );
    }
    return ColorFiltered(
      colorFilter: colorMatrix,
      child: Image.file(File(widget.path), fit: BoxFit.contain),
    );
  }

  Widget _topBar(BuildContext context, StudioSessionState session) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.md, vertical: StudioSpacing.sm),
      child: Row(
        children: [
          StudioButton(
            label: '',
            icon: Icons.close,
            variant: StudioButtonVariant.secondary,
            compact: true,
            onPressed: () => context.pop(),
          ),
          const Spacer(),
          StudioButton(
            label: 'Next',
            icon: Icons.arrow_forward,
            compact: true,
            onPressed: _goToPreview,
          ),
        ],
      ),
    );
  }

  Widget _trimAndCover() {
    final controller = _videoController;
    if (controller == null) return const SizedBox.shrink();
    return Container(
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: StudioSpacing.md, vertical: StudioSpacing.sm),
      child: TrimSlider(
        controller: controller,
        height: 56,
        horizontalMargin: 28,
        child: TrimTimeline(controller: controller, padding: const EdgeInsets.only(top: 8)),
      ),
    );
  }

  Widget _filterStrip() {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.md),
        itemCount: FilterRegistry.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: StudioSpacing.sm),
        itemBuilder: (context, index) {
          final f = FilterRegistry.all[index];
          final selected = f.id == _activeFilterId;
          return GestureDetector(
            onTap: () => _applyFilter(f.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.md),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? StudioColors.accent : StudioColors.surfaceRaised,
                borderRadius: BorderRadius.circular(StudioRadius.pill),
              ),
              child: Text(
                f.label,
                style: TextStyle(
                  color: selected ? Colors.white : StudioColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _applyFilter(String filterId) {
    setState(() => _activeFilterId = filterId);
    final layerId = _primaryVideoLayerId;
    if (layerId == null) return;
    ref.read(studioSessionProvider.notifier).execute(
          SetColorFilterCommand(layerId: layerId, filterId: filterId),
        );
  }

  void _addText() {
    final session = ref.read(studioSessionProvider);
    final textTrack = session.project.tracks.firstWhere((t) => t.kind == TrackKind.text);
    final layer = TextLayer(
      id: 'text_${DateTime.now().millisecondsSinceEpoch}',
      trackId: textTrack.id,
      text: 'Tap to edit',
      start: 0,
      duration: session.project.totalDuration == 0 ? fromSeconds(5) : session.project.totalDuration,
      transform: const StudioTransform(dx: 0.5, dy: 0.8),
      preset: StudioTextPreset.bold,
    );
    ref.read(studioSessionProvider.notifier).execute(AddLayerCommand(layer: layer));
  }

  void _addSticker() {
    final session = ref.read(studioSessionProvider);
    final stickerTrack = session.project.tracks.firstWhere(
      (t) => t.kind == TrackKind.sticker,
      orElse: () => session.project.tracks.first,
    );
    final layer = StickerLayer(
      id: 'sticker_${DateTime.now().millisecondsSinceEpoch}',
      trackId: stickerTrack.id,
      kind: StickerKind.emoji,
      payload: '🔥',
      start: 0,
      duration: fromSeconds(3),
      transform: const StudioTransform(dx: 0.5, dy: 0.5),
    );
    ref.read(studioSessionProvider.notifier).execute(AddLayerCommand(layer: layer));
  }

  void _addMusicPlaceholderNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Open the audio panel from the music track to add a track.')),
    );
  }

  void _deleteSelected() {
    final id = ref.read(studioSessionProvider).selectedLayerId;
    if (id == null) return;
    ref.read(studioSessionProvider.notifier).execute(DeleteLayerCommand(layerId: id));
  }

  void _goToPreview() {
    final controller = _videoController;
    if (controller != null) {
      final layerId = _primaryVideoLayerId;
      if (layerId != null) {
        ref.read(studioSessionProvider.notifier).execute(
              TrimClipCommand(
                layerId: layerId,
                newStart: 0,
                newDuration: (controller.endTrim - controller.startTrim).inMicroseconds,
                newSourceStart: controller.startTrim.inMicroseconds,
              ),
            );
      }
    }
    context.push('/studio/preview');
  }
}
