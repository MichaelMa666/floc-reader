class RemoteLibraryBook {
  const RemoteLibraryBook({
    required this.id,
    required this.file,
    required this.path,
    required this.category,
  });

  final String id;
  final String file;
  final String path;
  final String category;
}

class LibrarySyncFailure {
  const LibrarySyncFailure({
    required this.bookId,
    required this.file,
    required this.reason,
  });

  final String bookId;
  final String file;
  final String reason;
}

class LibrarySyncResult {
  const LibrarySyncResult({
    required this.importedCount,
    required this.skippedCount,
    required this.failedCount,
    required this.failures,
  });

  final int importedCount;
  final int skippedCount;
  final int failedCount;
  final List<LibrarySyncFailure> failures;
}
