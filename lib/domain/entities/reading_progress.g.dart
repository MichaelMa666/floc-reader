// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReadingProgress _$ReadingProgressFromJson(Map<String, dynamic> json) =>
    ReadingProgress(
      bookId: json['bookId'] as String,
      chapterId: json['chapterId'] as String,
      offset: (json['offset'] as num).toInt(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$ReadingProgressToJson(ReadingProgress instance) =>
    <String, dynamic>{
      'bookId': instance.bookId,
      'chapterId': instance.chapterId,
      'offset': instance.offset,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
