library;

import 'package:flutter/material.dart';

import '../entities/layer.dart';

/// Renders the text/sticker layers as positioned widgets, using each
/// layer's fractional [StudioTransform] mapped to [Alignment]. Both
/// `EditorScreen` (live editing) and `PreviewCanvas` (final check before
/// export) call this so a layer always looks the same in both places —
/// there is exactly one piece of code that turns a layer into pixels on
/// screen.
List<Widget> layerOverlayWidgets(Iterable<StudioLayer> activeLayers) {
  return activeLayers.map((layer) {
    return layer.map(
      video: (_) => const SizedBox.shrink(),
      image: (_) => const SizedBox.shrink(),
      audio: (_) => const SizedBox.shrink(),
      text: (l) => Align(
        key: ValueKey(l.id),
        alignment: Alignment(l.transform.dx * 2 - 1, l.transform.dy * 2 - 1),
        child: Opacity(
          opacity: l.transform.opacity,
          child: Transform.scale(
            scale: l.transform.scale,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l.text,
                textAlign: l.preset.align,
                style: TextStyle(
                  fontSize: l.preset.fontSize,
                  fontWeight: l.preset.fontWeight,
                  color: l.preset.color,
                  shadows: [
                    Shadow(
                      color: l.preset.strokeColor,
                      blurRadius: l.preset.strokeWidth,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      sticker: (l) => Align(
        key: ValueKey(l.id),
        alignment: Alignment(l.transform.dx * 2 - 1, l.transform.dy * 2 - 1),
        child: Opacity(
          opacity: l.transform.opacity,
          child: Transform.scale(
            scale: l.transform.scale,
            child: Text(l.payload, style: const TextStyle(fontSize: 40)),
          ),
        ),
      ),
    );
  }).toList();
}
