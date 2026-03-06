import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:floc_reader/app/app.dart';
import 'package:floc_reader/data/local/app_database.dart';
import 'package:floc_reader/shared/providers/app_providers.dart';

void main() {
  testWidgets('app starts with bookshelf page', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookListProvider.overrideWith((ref) => Future.value(<BookRow>[])),
        ],
        child: const FlocReaderApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('书架'), findsOneWidget);
  });
}
