library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../entities/project.dart';

part 'export_settings.freezed.dart';
part 'export_settings.g.dart';

enum ExportQuality { standard, high }

extension ExportQualityX on ExportQuality {
  int get targetHeightPx => switch (this) {
        ExportQuality.standard => 720,
        ExportQuality.high => 1080,
      };
}

@freezed
class ExportSettings with _$ExportSettings {
  const ExportSettings._();

  const factory ExportSettings({
    required AspectRatioPreset aspectRatio,
    @Default(ExportQuality.high) ExportQuality quality,
    @Default(true) bool includeAudio,
  }) = _ExportSettings;

  factory ExportSettings.fromJson(Map<String, dynamic> json) => _$ExportSettingsFromJson(json);

  int get targetWidthPx => (quality.targetHeightPx * aspectRatio.ratio).round();
}
