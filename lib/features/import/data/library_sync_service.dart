import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/repositories/book_repository.dart';
import 'library_sync_models.dart';

class LibrarySyncService {
  LibrarySyncService({required BookRepository repository, http.Client? client})
    : _repository = repository,
      _client = client ?? http.Client();

  static const String catalogUrl =
      'https://raw.githubusercontent.com/MichaelMa666/floc-reader-library/refs/heads/main/catalog.json';

  final BookRepository _repository;
  final http.Client _client;

  Future<LibrarySyncResult> sync() async {
    final books = await _fetchCatalogBooks();
    final docsDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(
      p.join(docsDir.path, 'floc_reader_library', 'books'),
    );
    await booksDir.create(recursive: true);

    var importedCount = 0;
    var skippedCount = 0;
    final failures = <LibrarySyncFailure>[];

    for (final book in books) {
      try {
        final sourceId = 'library:${book.id}';
        final existsNewSource = await _repository.existsBySourceId(sourceId);
        if (existsNewSource) {
          skippedCount++;
          continue;
        }

        final localRelativePath = _localRelativePath(book.path);
        final localFile = File(p.join(booksDir.path, localRelativePath));
        await localFile.parent.create(recursive: true);
        if (!await localFile.exists() || (await localFile.length()) == 0) {
          await _downloadBook(book, localFile);
        }

        final bytes = await localFile.readAsBytes();
        await _repository.importLocalBook(
          fileName: book.file,
          bytes: bytes,
          sourceId: sourceId,
          stableBookId: 'library_${book.id}',
          titleOverride: _titleFromFileName(book.file),
        );
        importedCount++;
      } catch (e) {
        failures.add(
          LibrarySyncFailure(
            bookId: book.id,
            file: book.file,
            reason: e.toString(),
          ),
        );
      }
    }

    return LibrarySyncResult(
      importedCount: importedCount,
      skippedCount: skippedCount,
      failedCount: failures.length,
      failures: failures,
    );
  }

  Future<List<RemoteLibraryBook>> _fetchCatalogBooks() async {
    final uri = Uri.parse(catalogUrl).replace(
      queryParameters: {
        't': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw HttpException('拉取 catalog 失败，状态码: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('catalog.json 格式错误');
    }

    final catalog = decoded['catalog'];
    final fallbackBookDir = catalog is Map<String, dynamic>
        ? (catalog['bookDir']?.toString() ?? 'books')
        : 'books';
    final rawBooks = decoded['books'];
    if (rawBooks is! List) {
      throw const FormatException('catalog.json 缺少 books 列表');
    }

    final books = <RemoteLibraryBook>[];
    for (final item in rawBooks) {
      _collectCatalogBooks(item, books, fallbackBookDir: fallbackBookDir);
    }

    return books;
  }

  void _collectCatalogBooks(
    Object? item,
    List<RemoteLibraryBook> output, {
    required String fallbackBookDir,
  }) {
    if (item is! Map<String, dynamic>) return;

    final id = item['id']?.toString().trim() ?? '';
    final file = item['file']?.toString().trim() ?? '';
    if (id.isNotEmpty && file.isNotEmpty) {
      var path = item['path']?.toString().trim() ?? '';
      if (path.isEmpty) {
        path = '$fallbackBookDir/$file';
      }
      output.add(RemoteLibraryBook(id: id, file: file, path: path));
      return;
    }

    final nested = item['books'];
    if (nested is List) {
      for (final child in nested) {
        _collectCatalogBooks(child, output, fallbackBookDir: fallbackBookDir);
      }
    }
  }

  Future<void> _downloadBook(RemoteLibraryBook book, File targetFile) async {
    final downloadUri = _resolveDownloadUri(book.path);
    final response = await _client.get(downloadUri);
    if (response.statusCode != 200) {
      throw HttpException('下载失败(${response.statusCode}): ${book.file}');
    }
    await targetFile.writeAsBytes(response.bodyBytes, flush: true);
  }

  Uri _resolveDownloadUri(String relativePath) {
    final catalogUri = Uri.parse(catalogUrl);
    final clean = relativePath
        .replaceAll('\\', '/')
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    final baseSegments = catalogUri.pathSegments.sublist(
      0,
      catalogUri.pathSegments.length - 1,
    );
    return Uri(
      scheme: catalogUri.scheme,
      host: catalogUri.host,
      pathSegments: [...baseSegments, ...clean],
    );
  }

  String _localRelativePath(String remotePath) {
    final segments = remotePath
        .replaceAll('\\', '/')
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    if (segments.isEmpty) return remotePath;
    if (segments.first == 'books' && segments.length > 1) {
      return p.joinAll(segments.skip(1));
    }
    return p.joinAll(segments);
  }

  String _titleFromFileName(String fileName) {
    final ext = p.extension(fileName);
    if (ext.isEmpty) return fileName;
    return p.basenameWithoutExtension(fileName);
  }
}
