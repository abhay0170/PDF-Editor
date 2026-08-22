import 'package:flutter/material.dart';

import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../database/app_database.dart';
import 'document_thumbnail.dart';

class RecentDocumentCard extends StatelessWidget {
  const RecentDocumentCard({super.key, required this.document, required this.onTap});

  final Document document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: document.displayName,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.mediumRadius,
        child: SizedBox(
          width: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DocumentThumbnail(document: document, width: 96, height: 128),
              const SizedBox(height: Spacing.sm),
              Text(
                document.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.titleMedium?.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
