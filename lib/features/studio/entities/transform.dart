library;

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transform.freezed.dart';
part 'transform.g.dart';

/// 2D transform applied to a visual layer on the canvas, expressed in
/// *fractional* canvas coordinates (0.0–1.0) so it stays valid no matter
/// what the export resolution ends up being.
@freezed
class StudioTransform with _$StudioTransform {
  const StudioTransform._();

  const factory StudioTransform({
    @Default(0.5) double dx,
    @Default(0.5) double dy,
    @Default(1.0) double scale,
    @Default(0.0) double rotationDegrees,
    @Default(1.0) double opacity,
    @Default(false) bool flipX,
    @Default(false) bool flipY,
  }) = _StudioTransform;

  factory StudioTransform.fromJson(Map<String, dynamic> json) =>
      _$StudioTransformFromJson(json);

  static const StudioTransform identity = StudioTransform();

  Offset get position => Offset(dx, dy);
}
