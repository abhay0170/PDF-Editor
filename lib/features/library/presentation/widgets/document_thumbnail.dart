import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../database/app_database.dart';
import '../../../../pdf/pdf_providers.dart';

/// Renders the document's real page-1 thumbnail once available, with a
/// quiet placeholder beforehand — never a fake/generic preview.
class DocumentThumbnail extends ConsumerWidget {
  const DocumentThumbnail({
    super.key,
    required this.document,
    this.width = 56,
    this.height = 76,
  });

  final Document document;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    Widget placeholder() => Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: Radii.smallRadius,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Icon(
        AppIcons.file,
        size: width * 0.4,
        color: theme.textTheme.bodyMedium?.color,
      ),
    );

    final thumbnailPath = document.thumbnailPath;
    if (thumbnailPath == null) return placeholder();

    final cachedBytes = ref.read(thumbnailCacheProvider).get(document.id);

    // Thumbnails are stored at a fixed larger resolution (CacheConstants) but
    // usually displayed much smaller (e.g. a 40x52 list row); decoding at the
    // display size instead of the stored size avoids holding a full-size
    // decoded bitmap in memory for every row on screen.
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (width * devicePixelRatio).round();
    final cacheHeight = (height * devicePixelRatio).round();

    final image = cachedBytes != null
        ? Image.memory(
            cachedBytes,
            width: width,
            height: height,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          )
        : Image.file(
            File(thumbnailPath),
            width: width,
            height: height,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => placeholder(),
          );

    return Container(
      decoration: BoxDecoration(
        borderRadius: Radii.smallRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: Radii.smallRadius, child: image),
    );
  }
}
