library;

import 'package:flutter/material.dart';

import '../entities/layer.dart';
import '../entities/project.dart';
import '../entities/track.dart';
import '../theme/studio_colors.dart';
import '../utils/typedefs.dart';

class TimelineWidget extends StatelessWidget {
  const TimelineWidget({
    super.key,
    required this.project,
    required this.playhead,
    this.selectedLayerId,
    this.onSeek,
    this.onLayerTap,
    this.pixelsPerSecond = 70,
  });

  final StudioProject project;
  final Microseconds playhead;
  final StudioId? selectedLayerId;
  final ValueChanged<Microseconds>? onSeek;
  final ValueChanged<StudioId>? onLayerTap;
  final double pixelsPerSecond;

  double get _totalWidth => (project.totalDuration.seconds * pixelsPerSecond) + 48;

  @override
  Widget build(BuildContext context) {
    final tracks = project.sortedTracks;
    if (tracks.isEmpty) {
      return const Center(
        child: Text('No clip yet', style: TextStyle(color: StudioColors.textTertiary)),
      );
    }

    return GestureDetector(
      onHorizontalDragUpdate: (details) => _seekFromLocalDx(details.localPosition.dx),
      onTapDown: (details) => _seekFromLocalDx(details.localPosition.dx),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _totalWidth,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final t in tracks) _trackRow(t)],
              ),
              _playheadLine(),
            ],
          ),
        ),
      ),
    );
  }

  void _seekFromLocalDx(double dx) {
    final t = fromSeconds(dx / pixelsPerSecond);
    onSeek?.call(t.clamp(0, project.totalDuration));
  }

  Widget _trackRow(StudioTrack track) {
    final layers = project.layersOnTrack(track.id);
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs),
            decoration: BoxDecoration(
              color: StudioColors.surfaceRaised.withOpacity(0.4),
              borderRadius: BorderRadius.circular(StudioRadius.sm),
            ),
          ),
          for (final layer in layers) _layerBlock(layer, track),
        ],
      ),
    );
  }

  Widget _layerBlock(StudioLayer layer, StudioTrack track) {
    final left = layer.startAt.seconds * pixelsPerSecond + StudioSpacing.xs;
    final width = (layer.durationMicros.seconds * pixelsPerSecond - StudioSpacing.xs).clamp(8.0, double.infinity);
    final selected = layer.layerId == selectedLayerId;
    final color = _colorFor(track.kind);

    return Positioned(
      left: left,
      top: 4,
      bottom: 4,
      width: width,
      child: GestureDetector(
        onTap: () => onLayerTap?.call(layer.layerId),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.85),
            borderRadius: BorderRadius.circular(StudioRadius.sm),
            border: Border.all(color: selected ? Colors.white : color, width: selected ? 2 : 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.centerLeft,
          child: Text(
            _labelFor(layer),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _playheadLine() {
    final left = playhead.seconds * pixelsPerSecond;
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(width: 2, color: StudioColors.accent),
      ),
    );
  }

  String _labelFor(StudioLayer layer) => layer.map(
        video: (_) => 'Video',
        image: (_) => 'Image',
        text: (l) => l.text,
        sticker: (l) => l.payload,
        audio: (_) => 'Audio',
      );

  Color _colorFor(TrackKind kind) => switch (kind) {
        TrackKind.video => StudioColors.trackVideo,
        TrackKind.image => StudioColors.trackVideo,
        TrackKind.text => StudioColors.trackText,
        TrackKind.sticker => StudioColors.trackSticker,
        TrackKind.music => StudioColors.trackAudio,
        TrackKind.voiceover => StudioColors.trackAudio,
      };
}
