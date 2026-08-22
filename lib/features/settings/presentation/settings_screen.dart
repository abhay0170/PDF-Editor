import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/icons.dart';
import '../../../app/theme/radii.dart';
import '../../../app/theme/spacing.dart';
import 'default_storage_provider.dart';
import 'theme_mode_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _pickDefaultFolder(BuildContext context, WidgetRef ref) async {
    final path = await FilePicker.getDirectoryPath(dialogTitle: 'Choose default folder');
    if (path != null) {
      await ref.read(defaultStorageProvider.notifier).setFolder(path);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final defaultStorage = ref.watch(defaultStorageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.screenHorizontal,
          vertical: Spacing.lg,
        ),
        children: [
          _SectionLabel('Appearance'),
          _SettingsGroup(
            children: [
              _RadioRow(
                icon: AppIcons.system,
                label: 'System',
                selected: themeMode == ThemeMode.system,
                onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
              ),
              _RadioRow(
                icon: AppIcons.sun,
                label: 'Light',
                selected: themeMode == ThemeMode.light,
                onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
              ),
              _RadioRow(
                icon: AppIcons.moon,
                label: 'Dark',
                selected: themeMode == ThemeMode.dark,
                onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sectionSpacing),
          _SectionLabel('Storage'),
          _SettingsGroup(
            children: [
              _FolderRow(
                label: 'Default storage',
                value: defaultStorage,
                onTap: () => _pickDefaultFolder(context, ref),
                onClear: defaultStorage == null
                    ? null
                    : () => ref.read(defaultStorageProvider.notifier).setFolder(null),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sectionSpacing),
          _SectionLabel('About'),
          const _SettingsGroup(
            children: [_InfoRow(label: 'Version', value: '1.0.0')],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: Spacing.sm, bottom: Spacing.sm),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(letterSpacing: 0.4),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: Radii.largeRadius,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, indent: Spacing.lg, color: Theme.of(context).dividerColor),
          ],
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.textTheme.bodyMedium?.color),
              const SizedBox(width: Spacing.md),
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              if (selected)
                Icon(AppIcons.check, size: 20, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
        child: Row(
          children: [
            Icon(AppIcons.folder, size: 20, color: theme.textTheme.bodyMedium?.color),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyLarge),
                  Text(
                    value ?? 'Ask each time',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(icon: Icon(AppIcons.close, size: 18), tooltip: 'Clear', onPressed: onClear),
            Icon(AppIcons.chevronRight, size: 18, color: theme.textTheme.bodySmall?.color),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyLarge),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
