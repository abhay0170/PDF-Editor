import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/features/tools/scan/presentation/scan_screen.dart';

void main() {
  testWidgets('shows the empty state before any page is scanned', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ScanScreen())),
    );
    await tester.pump();

    expect(find.text('Scan one page'), findsOneWidget);
    expect(find.text('Scan multiple pages'), findsOneWidget);
    // The FAB (and reorderable page list) only appear once a page exists.
    expect(find.text('Save as PDF'), findsNothing);
  });
}
