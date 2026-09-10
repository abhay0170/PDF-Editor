import 'package:flutter/material.dart';

import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';

class ViewerBottomBar extends StatelessWidget {
  const ViewerBottomBar({
    super.key,
    required this.isBookmarked,
    required this.onSearch,
    required this.onToggleBookmark,
    required this.onInfo,
  });

  final bool isBookmarked;
  final VoidCallback? onSearch;
  final VoidCallback onToggleBookmark;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Spacing.xxl,
        0,
        Spacing.xxl,
        MediaQuery.of(context).padding.bottom + Spacing.lg,
      ),
      child: Container(
        height: Spacing.toolbarHeight,
        decoration: BoxDecoration(
          color: theme.cardColor.withValues(alpha: 0.94),
          borderRadius: Radii.extraLargeRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(AppIcons.search),
              tooltip: 'Search',
              onPressed: onSearch,
            ),
            IconButton(
              icon: Icon(
                AppIcons.bookmark,
                color: isBookmarked ? theme.colorScheme.primary : null,
              ),
              tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
              onPressed: onToggleBookmark,
            ),
            IconButton(
              icon: const Icon(AppIcons.info),
              tooltip: 'Document info',
              onPressed: onInfo,
            ),
          ],
        ),
      ),
    );
  }
}
