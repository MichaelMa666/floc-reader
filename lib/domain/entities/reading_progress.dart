import 'package:json_annotation/json_annotation.dart';

part 'reading_progress.g.dart';

@JsonSerializable()
class ReadingProgress {
  const ReadingProgress({
    required this.bookId,
    required this.chapterId,
    required this.offset,
    required this.updatedAt,
  });

  final String bookId;
  final String chapterId;
  final int offset;
  final DateTime updatedAt;

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return _$ReadingProgressFromJson(json);
  }

  Map<String, dynamic> toJson() => _$ReadingProgressToJson(this);
}
