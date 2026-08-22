import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';

class _QuickTool {
  const _QuickTool(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final void Function(BuildContext context) onTap;
}

/// All nine tools — this row (with "Show more") is now the only way to
/// reach a tool, since the separate Tools tab/screen was removed in favor
/// of a single home page.
final List<_QuickTool> _quickTools = [
  _QuickTool(AppIcons.scan, 'Scan', (context) => AppRoutes.openScan(context)),
  _QuickTool(AppIcons.merge, 'Merge', (context) => AppRoutes.openMerge(context)),
  _QuickTool(AppIcons.split, 'Split', (context) => AppRoutes.openSplit(context)),
  _QuickTool(AppIcons.rotate, 'Rotate', (context) => AppRoutes.openRotate(context)),
  _QuickTool(AppIcons.extract, 'Extract', (context) => AppRoutes.openExtract(context)),
  _QuickTool(AppIcons.watermark, 'Watermark', (context) => AppRoutes.openWatermark(context)),
  _QuickTool(AppIcons.compress, 'Compress', (context) => AppRoutes.openCompress(context)),
  _QuickTool(AppIcons.sign, 'Sign', (context) => AppRoutes.openSign(context)),
  _QuickTool(AppIcons.ocr, 'Searchable', (context) => AppRoutes.openOcr(context)),
];

/// Grid columns for the tools layout.
const int _columns = 3;

/// Number of tools shown before "Show more" is needed — collapsed layout is
/// this many tools plus a "Show more" tile, filling a full 3x2 grid.
const int _collapsedCount = 5;

/// A grid of shortcuts into every tool — shown on the Library/home screen
/// (both the empty state and, compactly, above the document list). Starts
/// collapsed to the most commonly used tools, with "Show more" filling the
/// last slot of the grid; tapping it reveals the rest in place. This is now
/// the only way to reach a tool (the separate Tools tab/screen was removed).
class QuickToolsRow extends HookWidget {
  const QuickToolsRow({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: Spacing.screenHorizontal),
  });

  /// Defaults to the standard screen-edge inset, for placing this directly
  /// inside a full-width scroll view. Pass [EdgeInsets.zero] when the caller
  /// already applies its own horizontal inset (e.g. the centered empty
  /// state), so the row's edges line up with surrounding content instead of
  /// being indented twice.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final expanded = useState(false);
    final hasMore = _quickTools.length > _collapsedCount;
    final visibleTools = expanded.value ? _quickTools : _quickTools.take(_collapsedCount).toList();

    final cells = <Widget>[
      for (final tool in visibleTools) _QuickToolTile(icon: tool.icon, label: tool.label, onTap: () => tool.onTap(context)),
      if (hasMore && !expanded.value)
        _QuickToolTile(
          icon: AppIcons.more,
          label: 'Show more',
          onTap: () => expanded.value = true,
        ),
    ];

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cells.length; i += _columns) ...[
            if (i > 0) const SizedBox(height: Spacing.sm),
            _QuickToolGridRow(cells: cells.skip(i).take(_columns).toList()),
          ],
          if (hasMore && expanded.value) ...[
            const SizedBox(height: Spacing.sm),
            TextButton.icon(
              onPressed: () => expanded.value = false,
              icon: Icon(AppIcons.chevronUp, size: 16),
              label: const Text('Show less'),
            ),
          ],
        ],
      ),
    );
  }
}

/// One row of the tools grid. Pads a trailing partial row with empty space
/// so tiles keep a consistent column width instead of stretching.
class _QuickToolGridRow extends StatelessWidget {
  const _QuickToolGridRow({required this.cells});

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _columns; i++) ...[
          if (i > 0) const SizedBox(width: Spacing.sm),
          Expanded(child: i < cells.length ? cells[i] : const SizedBox.shrink()),
        ],
      ],
    );
  }
}

class _QuickToolTile extends StatelessWidget {
  const _QuickToolTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.mediumRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: Radii.mediumRadius,
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.primary),
            const SizedBox(height: Spacing.xs),
            Text(
              label,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
