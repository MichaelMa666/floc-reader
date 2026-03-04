import 'package:json_annotation/json_annotation.dart';

part 'reading_config.g.dart';

@JsonSerializable()
class ReadingConfig {
  const ReadingConfig({
    required this.fontSize,
    required this.lineHeight,
    required this.nightMode,
    required this.brightness,
  });

  final double fontSize;
  final double lineHeight;
  final bool nightMode;
  final double brightness;

  factory ReadingConfig.fromJson(Map<String, dynamic> json) {
    return _$ReadingConfigFromJson(json);
  }

  Map<String, dynamic> toJson() => _$ReadingConfigToJson(this);
}
