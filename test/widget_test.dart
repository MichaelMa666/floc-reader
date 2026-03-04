import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:floc_reader/app/app.dart';

void main() {
  testWidgets('app starts with bookshelf page', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FlocReaderApp()));
    await tester.pumpAndSettle();
    expect(find.text('书架'), findsOneWidget);
  });
}
