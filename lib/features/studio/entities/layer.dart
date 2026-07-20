library;

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/typedefs.dart';
import 'converters.dart';
import 'transform.dart';

part 'layer.freezed.dart';
part 'layer.g.dart';

/// Every visible/audible thing on the timeline is a [StudioLayer]. Using a
/// Freezed sealed class instead of one bloated model means the compiler
/// forces every `.when`/`.map` call site to handle new variants — no
/// silent gaps when a new layer kind is added later (face filters, etc).
@freezed
sealed class StudioLayer with _$StudioLayer {
  const StudioLayer._();

  const factory StudioLayer.video({
    required StudioId id,
    required StudioId trackId,
    required StudioId sourceId,
    required Microseconds start,
    required Microseconds duration,
    @Default(0) Microseconds sourceStart,
    @Default(1.0) double speed,
    @Default(1.0) double volume,
    @Default(StudioTransform.identity) StudioTransform transform,
    @Default('none') String colorFilterId,
  }) = VideoLayer;

  const factory StudioLayer.image({
    required StudioId id,
    required StudioId trackId,
    required StudioId sourceId,
    required Microseconds start,
    required Microseconds duration,
    @Default(StudioTransform.identity) StudioTransform transform,
  }) = ImageLayer;

  const factory StudioLayer.text({
    required StudioId id,
    required StudioId trackId,
    required String text,
    required Microseconds start,
    required Microseconds duration,
    @Default(StudioTransform.identity) StudioTransform transform,
    @Default(StudioTextPreset.bold) StudioTextPreset preset,
  }) = TextLayer;

  const factory StudioLayer.sticker({
    required StudioId id,
    required StudioId trackId,
    required StickerKind kind,
    required String payload, // emoji glyph, GIF url, or asset path
    required Microseconds start,
    required Microseconds duration,
    @Default(StudioTransform.identity) StudioTransform transform,
  }) = StickerLayer;

  const factory StudioLayer.audio({
    required StudioId id,
    required StudioId trackId,
    required StudioId sourceId,
    required Microseconds start,
    required Microseconds duration,
    @Default(0) Microseconds sourceStart,
    @Default(1.0) double volume,
    @Default(0) int fadeInMs,
    @Default(0) int fadeOutMs,
  }) = AudioLayer;

  StudioId get layerId => map(
        video: (l) => l.id,
        image: (l) => l.id,
        text: (l) => l.id,
        sticker: (l) => l.id,
        audio: (l) => l.id,
      );

  StudioId get trackRef => map(
        video: (l) => l.trackId,
        image: (l) => l.trackId,
        text: (l) => l.trackId,
        sticker: (l) => l.trackId,
        audio: (l) => l.trackId,
      );

  Microseconds get startAt => map(
        video: (l) => l.start,
        image: (l) => l.start,
        text: (l) => l.start,
        sticker: (l) => l.start,
        audio: (l) => l.start,
      );

  Microseconds get durationMicros => map(
        video: (l) => l.duration,
        image: (l) => l.duration,
        text: (l) => l.duration,
        sticker: (l) => l.duration,
        audio: (l) => l.duration,
      );

  Microseconds get endAt => startAt + durationMicros;

  bool get isAudible => this is AudioLayer || this is VideoLayer;
  bool get isVisual => this is! AudioLayer;

  bool isActiveAt(Microseconds t) => t >= startAt && t < endAt;

  factory StudioLayer.fromJson(Map<String, dynamic> json) =>
      _$StudioLayerFromJson(json);
}

enum StickerKind { emoji, gif, animated }

@freezed
class StudioTextPreset with _$StudioTextPreset {
  const factory StudioTextPreset({
    @Default(44) double fontSize,
    @ColorConverter() @Default(Color(0xFFFFFFFF)) Color color,
    @ColorConverter() @Default(Color(0xFF000000)) Color strokeColor,
    @Default(2.5) double strokeWidth,
    @FontWeightConverter() @Default(FontWeight.w800) FontWeight fontWeight,
    @TextAlignConverter() @Default(TextAlign.center) TextAlign align,
  }) = _StudioTextPreset;

  factory StudioTextPreset.fromJson(Map<String, dynamic> json) =>
      _$StudioTextPresetFromJson(json);

  static const StudioTextPreset bold = StudioTextPreset();

  static const StudioTextPreset subtitle = StudioTextPreset(
    fontSize: 32,
    color: Color(0xFFFFD60A),
    strokeWidth: 1.5,
    fontWeight: FontWeight.w600,
  );
}
