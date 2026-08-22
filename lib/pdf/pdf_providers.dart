import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cache/thumbnail_cache.dart';
import 'engine/pdf_engine.dart';

final pdfEngineProvider = Provider<PdfEngine>((ref) => PdfrxEngine());

final thumbnailCacheProvider = Provider<ThumbnailCache>((ref) => ThumbnailCache());
