import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/app/theme/app_theme.dart';
import 'package:pdf_reader/app/theme/color_tokens.dart';

void main() {
  testWidgets('light theme renders with the spec background/accent tokens', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Text('Light')),
      ),
    );

    final context = tester.element(find.text('Light'));
    final theme = Theme.of(context);

    expect(theme.scaffoldBackgroundColor, LightColors.background);
    expect(theme.colorScheme.primary, LightColors.accent);
    expect(theme.colorScheme.brightness, Brightness.light);
  });

  testWidgets('dark theme renders with the spec background/accent tokens', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: Text('Dark')),
      ),
    );

    final context = tester.element(find.text('Dark'));
    final theme = Theme.of(context);

    expect(theme.scaffoldBackgroundColor, DarkColors.background);
    expect(theme.colorScheme.primary, DarkColors.accent);
    expect(theme.colorScheme.brightness, Brightness.dark);
  });
}
