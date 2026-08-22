import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/tool_colors.dart';

class _QuickTool {
  const _QuickTool({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;

  /// Null means the tool has no destination yet — the tile renders dimmed
  /// with a "Soon" badge instead of navigating.
  final void Function(BuildContext context)? onTap;
}

/// The always-visible 3x3 grid — mirrors the reference design's fixed tile
/// count. "More" reveals [_moreTools] below rather than replacing any of
/// these nine.
final List<_QuickTool> _primaryTools = [
  _QuickTool(
    icon: AppIcons.scan,
    label: 'Scan',
    subtitle: 'Scan new document',
    color: ToolColors.scan,
    onTap: (context) => AppRoutes.openScan(context),
  ),
  _QuickTool(
    icon: AppIcons.merge,
    label: 'Merge',
    subtitle: 'Combine PDFs',
    color: ToolColors.merge,
    onTap: (context) => AppRoutes.openMerge(context),
  ),
  _QuickTool(
    icon: AppIcons.split,
    label: 'Split',
    subtitle: 'Split a PDF',
    color: ToolColors.split,
    onTap: (context) => AppRoutes.openSplit(context),
  ),
  _QuickTool(
    icon: AppIcons.compress,
    label: 'Compress',
    subtitle: 'Reduce file size',
    color: ToolColors.compress,
    onTap: (context) => AppRoutes.openCompress(context),
  ),
  _QuickTool(
    icon: AppIcons.extract,
    label: 'Extract',
    subtitle: 'Extract pages',
    color: ToolColors.extract,
    onTap: (context) => AppRoutes.openExtract(context),
  ),
  _QuickTool(
    icon: AppIcons.rotate,
    label: 'Rotate',
    subtitle: 'Rotate pages',
    color: ToolColors.rotate,
    onTap: (context) => AppRoutes.openRotate(context),
  ),
  const _QuickTool(
    icon: AppIcons.lock,
    label: 'Protect',
    subtitle: 'Lock your PDF',
    color: ToolColors.protect,
  ),
  const _QuickTool(
    icon: AppIcons.image,
    label: 'Convert',
    subtitle: 'PDF to image',
    color: ToolColors.convert,
  ),
];

/// Extra tools folded under "More" — real, working destinations that just
/// don't fit the reference's fixed 3x3 layout.
final List<_QuickTool> _moreTools = [
  _QuickTool(
    icon: AppIcons.watermark,
    label: 'Watermark',
    subtitle: 'Add a watermark',
    color: ToolColors.watermark,
    onTap: (context) => AppRoutes.openWatermark(context),
  ),
  _QuickTool(
    icon: AppIcons.sign,
    label: 'Sign',
    subtitle: 'Sign a document',
    color: ToolColors.sign,
    onTap: (context) => AppRoutes.openSign(context),
  ),
  _QuickTool(
    icon: AppIcons.ocr,
    label: 'Searchable',
    subtitle: 'Make text searchable',
    color: ToolColors.ocr,
    onTap: (context) => AppRoutes.openOcr(context),
  ),
];

/// Grid columns for the tools layout.
const int _columns = 3;

/// A fixed 3x3 grid of shortcuts into every tool — shown on the Home screen
/// (both the empty state and, compactly, above the document list). The
/// last tile is always "More", which reveals [_moreTools] in an extra row
/// below rather than replacing any of the nine visible tiles.
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

    final primaryCells = [
      for (final tool in _primaryTools)
        _QuickToolTile(
          icon: tool.icon,
          label: tool.label,
          subtitle: tool.subtitle,
          color: tool.color,
          onTap: tool.onTap == null ? null : () => tool.onTap!(context),
        ),
      _QuickToolTile(
        icon: expanded.value ? AppIcons.chevronUp : AppIcons.more,
        label: expanded.value ? 'Less' : 'More',
        subtitle: 'More tools',
        color: ToolColors.more,
        onTap: () => expanded.value = !expanded.value,
      ),
    ];

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToolGrid(cells: primaryCells),
          if (expanded.value) ...[
            const SizedBox(height: Spacing.sm),
            _ToolGrid(
              cells: [
                for (final tool in _moreTools)
                  _QuickToolTile(
                    icon: tool.icon,
                    label: tool.label,
                    subtitle: tool.subtitle,
                    color: tool.color,
                    onTap: tool.onTap == null ? null : () => tool.onTap!(context),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Lays out [cells] in rows of [_columns], padding a trailing partial row
/// with empty space so tiles keep a consistent column width instead of
/// stretching.
class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.cells});

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < cells.length; i += _columns) ...[
          if (i > 0) const SizedBox(height: Spacing.sm),
          Row(
            children: [
              for (var col = 0; col < _columns; col++) ...[
                if (col > 0) const SizedBox(width: Spacing.sm),
                Expanded(child: i + col < cells.length ? cells[i + col] : const SizedBox.shrink()),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _QuickToolTile extends StatelessWidget {
  const _QuickToolTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;

  /// Null renders the tile dimmed with a "Soon" badge instead of a working
  /// shortcut.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap:
            onTap ??
            () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Coming soon'))),
        borderRadius: Radii.mediumRadius,
        child: Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: Radii.mediumRadius,
            border: Border.all(color: theme.dividerColor),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: Radii.smallRadius,
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (!enabled)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: Radii.smallRadius,
                    ),
                    child: Text('Soon', style: theme.textTheme.labelSmall),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
