// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReadingConfig _$ReadingConfigFromJson(Map<String, dynamic> json) =>
    ReadingConfig(
      fontSize: (json['fontSize'] as num).toDouble(),
      lineHeight: (json['lineHeight'] as num).toDouble(),
      nightMode: json['nightMode'] as bool,
      brightness: (json['brightness'] as num).toDouble(),
    );

Map<String, dynamic> _$ReadingConfigToJson(ReadingConfig instance) =>
    <String, dynamic>{
      'fontSize': instance.fontSize,
      'lineHeight': instance.lineHeight,
      'nightMode': instance.nightMode,
      'brightness': instance.brightness,
    };
