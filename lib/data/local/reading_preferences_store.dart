import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/reading_config.dart';
import '../../domain/entities/reading_progress.dart';

class ReadingPreferencesStore {
  static const String _readingConfigKey = 'reading_config';
  static const String _readingProgressPrefix = 'reading_progress_';

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
}
