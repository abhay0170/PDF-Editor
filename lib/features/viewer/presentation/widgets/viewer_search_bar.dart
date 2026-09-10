import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';

class ViewerSearchBar extends HookWidget {
  const ViewerSearchBar({super.key, required this.searcher, required this.onClose});

  final PdfTextSearcher searcher;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    useListenable(searcher);
    final theme = Theme.of(context);
    final controller = useTextEditingController();

    final resultLabel = searcher.hasMatches
        ? '${(searcher.currentIndex ?? 0) + 1} / ${searcher.matches.length}'
        : (searcher.isSearching ? 'Searching…' : (controller.text.isEmpty ? '' : 'No results'));

    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + Spacing.sm),
      color: theme.scaffoldBackgroundColor.withValues(alpha: 0.96),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.screenHorizontal,
          vertical: Spacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: Radii.mediumRadius,
                  border: Border.all(color: theme.dividerColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                child: Row(
                  children: [
                    Icon(AppIcons.search, size: 18, color: theme.textTheme.bodyMedium?.color),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search in document',
                          isDense: true,
                        ),
                        onSubmitted: (value) => searcher.startTextSearch(value),
                        onChanged: (value) {
                          if (value.isEmpty) searcher.resetTextSearch();
                        },
                      ),
                    ),
                    if (resultLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: Spacing.xs),
                        child: Text(resultLabel, style: theme.textTheme.bodySmall),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(AppIcons.chevronLeft, size: 20),
              tooltip: 'Previous match',
              onPressed: searcher.hasMatches ? searcher.goToPrevMatch : null,
            ),
            IconButton(
              icon: Icon(AppIcons.chevronRight, size: 20),
              tooltip: 'Next match',
              onPressed: searcher.hasMatches ? searcher.goToNextMatch : null,
            ),
            IconButton(
              icon: Icon(AppIcons.close, size: 20),
              tooltip: 'Close search',
              onPressed: () {
                searcher.resetTextSearch();
                onClose();
              },
            ),
          ],
        ),
      ),
    );
  }
}
