import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/reading_config.dart';
import '../../domain/entities/reading_progress.dart';

class ReadingPreferencesStore {
  static const String _readingConfigKey = 'reading_config';
  static const String _readingProgressPrefix = 'reading_progress_';
  static const String _chapterProgressPrefix = 'chapter_progress_';

  Future<ReadingConfig?> getReadingConfig() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_readingConfigKey);
    if (raw == null) {
      return null;
    }
    return ReadingConfig.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  Future<void> saveReadingConfig(ReadingConfig config) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_readingConfigKey, jsonEncode(config.toJson()));
  }

  Future<ReadingProgress?> getLatestReadingProgress() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    ReadingProgress? latest;
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_readingProgressPrefix)) continue;
      final String? raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final progress = ReadingProgress.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (latest == null || progress.updatedAt.isAfter(latest.updatedAt)) {
          latest = progress;
        }
      } catch (_) {
        // 忽略格式异常的历史记录
      }
    }
    return latest;
  }

  Future<ReadingProgress?> getReadingProgress(String bookId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('$_readingProgressPrefix$bookId');
    if (raw == null) {
      return null;
    }
    return ReadingProgress.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  Future<void> saveReadingProgress(ReadingProgress progress) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_readingProgressPrefix${progress.bookId}',
      jsonEncode(progress.toJson()),
    );
  }

  Future<Map<String, int>> getChapterReadPercents(String bookId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('$_chapterProgressPrefix$bookId');
    if (raw == null || raw.trim().isEmpty) {
      return <String, int>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return <String, int>{};
    }
    final result = <String, int>{};
    decoded.forEach((key, value) {
      if (key.trim().isEmpty || value is! num) return;
      result[key] = value.toInt().clamp(0, 100);
    });
    return result;
  }

  Future<void> saveChapterReadPercent({
    required String bookId,
    required String chapterId,
    required int percent,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final safePercent = percent.clamp(0, 100);
    final progressMap = await getChapterReadPercents(bookId);
    final existing = progressMap[chapterId] ?? 0;
    // 只增不减，避免用户回滚到前面导致已读进度倒退。
    progressMap[chapterId] = safePercent > existing ? safePercent : existing;
    await prefs.setString(
      '$_chapterProgressPrefix$bookId',
      jsonEncode(progressMap),
    );
  }

  Future<void> clearReadingProgress() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final keysToRemove = prefs
        .getKeys()
        .where(
          (key) =>
              key.startsWith(_readingProgressPrefix) ||
              key.startsWith(_chapterProgressPrefix),
        )
        .toList();
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }
}
