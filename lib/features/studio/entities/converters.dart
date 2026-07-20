library;

import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

/// Freezed/json_serializable don't know how to (de)serialize Flutter's
/// [Color], [FontWeight] or [TextAlign] out of the box — these converters
/// plug that gap so `StudioTextPreset.fromJson/toJson` actually round-trips
/// instead of throwing at runtime.
class ColorConverter implements JsonConverter<Color, int> {
  const ColorConverter();

  @override
  Color fromJson(int json) => Color(json);

  // ignore: deprecated_member_use
  @override
  int toJson(Color object) => object.value;
}

class FontWeightConverter implements JsonConverter<FontWeight, int> {
  const FontWeightConverter();

  @override
  FontWeight fromJson(int json) => FontWeight.values.firstWhere(
        (w) => w.index == json,
        orElse: () => FontWeight.w400,
      );

  @override
  int toJson(FontWeight object) => object.index;
}

class TextAlignConverter implements JsonConverter<TextAlign, String> {
  const TextAlignConverter();

  @override
  TextAlign fromJson(String json) => TextAlign.values.firstWhere(
        (a) => a.name == json,
        orElse: () => TextAlign.center,
      );

  @override
  String toJson(TextAlign object) => object.name;
}
