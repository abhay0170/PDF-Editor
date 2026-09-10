import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/features/tools/scan/presentation/providers/scan_draft_controller.dart';
import 'package:pdf_reader/features/tools/scan/presentation/scan_screen.dart';

/// Overrides `build()` so the draft is available synchronously with no real
/// database access — a plain `overrideWith` value can't be used since
/// [ScanDraftController] is an [AsyncNotifier] backed by a live DAO read.
class _FakeScanDraftController extends ScanDraftController {
  _FakeScanDraftController(this._draft);

  final List<String> _draft;

  @override
  Future<List<String>> build() async => _draft;
}

void main() {
  testWidgets('auto-starts the scanner and shows a loading indicator while it opens', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // No draft on disk — without this override the screen falls through
        // to the real ScanDraftController, which opens an actual native
        // sqlite connection to check for one, leaving a pending timer this
        // single-frame test never settles.
        overrides: [scanDraftControllerProvider.overrideWith(() => _FakeScanDraftController(const []))],
        child: const MaterialApp(home: ScanScreen()),
      ),
    );

    // The screen skips its own "choose a scan type" landing page entirely —
    // the native scanner opens the instant this screen is pushed (see the
    // useEffect in ScanScreen.build), so before any page comes back the only
    // thing on screen is a loading state.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save as PDF'), findsNothing);
  });

  testWidgets('resumes a saved draft instead of auto-starting the scanner', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scanDraftControllerProvider.overrideWith(() => _FakeScanDraftController(const ['/tmp/draft_page1.jpg'])),
        ],
        child: const MaterialApp(home: ScanScreen()),
      ),
    );
    await tester.pump();

    // The previously scanned page is restored straight into the page list —
    // no scanner/picker was invoked, and the "Save as PDF" action is already
    // available for it.
    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('Save as PDF'), findsOneWidget);
  });
}
