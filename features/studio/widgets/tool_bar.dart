library;

import 'package:flutter/material.dart';

import '../theme/studio_colors.dart';

class ToolBar extends StatelessWidget {
  const ToolBar({
    super.key,
    required this.hasSelection,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onAddText,
    required this.onAddSticker,
    required this.onAddMusic,
    required this.onFilters,
    required this.onSplit,
    required this.onDelete,
  });

  final bool hasSelection;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onAddText;
  final VoidCallback onAddSticker;
  final VoidCallback onAddMusic;
  final VoidCallback onFilters;
  final VoidCallback onSplit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.md, vertical: StudioSpacing.sm),
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(top: BorderSide(color: StudioColors.separator, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ToolIcon(icon: Icons.undo, label: 'Undo', onTap: canUndo ? onUndo : null),
          _ToolIcon(icon: Icons.redo, label: 'Redo', onTap: canRedo ? onRedo : null),
          _ToolIcon(icon: Icons.text_fields, label: 'Text', onTap: onAddText, accent: true),
          _ToolIcon(icon: Icons.emoji_emotions_outlined, label: 'Sticker', onTap: onAddSticker),
          _ToolIcon(icon: Icons.music_note, label: 'Music', onTap: onAddMusic),
          _ToolIcon(icon: Icons.filter_vintage_outlined, label: 'Filter', onTap: hasSelection ? onFilters : null),
          _ToolIcon(icon: Icons.content_cut, label: 'Split', onTap: hasSelection ? onSplit : null),
          _ToolIcon(icon: Icons.delete_outline, label: 'Delete', onTap: hasSelection ? onDelete : null, destructive: true),
        ],
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool accent;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final color = disabled
        ? StudioColors.textTertiary
        : destructive
            ? StudioColors.error
            : accent
                ? StudioColors.accent
                : StudioColors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.4 : 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
