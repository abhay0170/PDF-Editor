import 'package:flutter/material.dart';

import '../../../../app/theme/icons.dart';
import '../../../../app/theme/spacing.dart';

class ViewerTopBar extends StatelessWidget {
  const ViewerTopBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.onMore,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: SizedBox(
        height: Spacing.toolbarHeight,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(AppIcons.back),
              tooltip: 'Back',
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: const Icon(AppIcons.more),
              tooltip: 'More',
              onPressed: onMore,
            ),
          ],
        ),
      ),
    );
  }
}
