import 'dart:io';

import 'package:drift/drift.dart' hide Table;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dir.path, 'floc_reader.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

class AppDatabase {
  AppDatabase() : connection = DatabaseConnection(_openConnection());

  final DatabaseConnection connection;
}
