library;

import 'package:flutter/material.dart';

import '../theme/studio_colors.dart';

enum StudioButtonVariant { primary, secondary, ghost }

class StudioButton extends StatefulWidget {
  const StudioButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = StudioButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = false,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final StudioButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final bool compact;

  @override
  State<StudioButton> createState() => _StudioButtonState();
}

class _StudioButtonState extends State<StudioButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 100));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;
    final height = widget.compact ? 40.0 : 52.0;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => _controller.forward(),
      onTapUp: disabled
          ? null
          : (_) {
              _controller.reverse();
              widget.onPressed?.call();
            },
      onTapCancel: disabled ? null : () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1 - (_controller.value * 0.05);
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          height: height,
          width: widget.fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.lg),
          decoration: BoxDecoration(
            color: _backgroundColor(disabled),
            borderRadius: BorderRadius.circular(StudioRadius.md),
            border: widget.variant == StudioButtonVariant.secondary
                ? Border.all(color: StudioColors.separator)
                : null,
          ),
          child: _content(disabled),
        ),
      ),
    );
  }

  Color _backgroundColor(bool disabled) {
    if (disabled) return StudioColors.surfaceRaised.withOpacity(0.5);
    return switch (widget.variant) {
      StudioButtonVariant.primary => StudioColors.accent,
      StudioButtonVariant.secondary => StudioColors.surfaceRaised,
      StudioButtonVariant.ghost => Colors.transparent,
    };
  }

  Widget _content(bool disabled) {
    final color = disabled
        ? StudioColors.textTertiary
        : widget.variant == StudioButtonVariant.primary
            ? Colors.white
            : StudioColors.textPrimary;

    if (widget.isLoading) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) Icon(widget.icon, color: color, size: 20),
        if (widget.icon != null && widget.label.isNotEmpty) const SizedBox(width: StudioSpacing.sm),
        if (widget.label.isNotEmpty)
          Text(widget.label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    );
  }
}
