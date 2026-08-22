# pdf

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Project structure

Architecture is feature-first MVVM on Riverpod: `*_screen.dart` = View, `*_controller.dart` (a Riverpod `Notifier`) = ViewModel, `domain/*_state.dart` = Model.

```
lib/
├── main.dart                 # App entry point
├── app/                      # App shell: routing, theming (not feature-specific)
│   ├── app.dart               # MaterialApp / root widget
│   ├── router.dart            # Route definitions
│   └── theme/                 # Colors, typography, spacing, icons, radii
│
├── core/                     # Cross-cutting helpers with no UI, shared by everything
│   ├── constants/              # Cache/storage constants
│   ├── errors/                 # Exception types
│   ├── performance/             # Memory monitor, perf logger
│   └── utils/                  # Formatters, page-range parsing, etc.
│
├── database/                 # Drift (SQLite) persistence layer
│   ├── app_database.dart        # Database definition (+ generated .g.dart)
│   ├── tables/                  # Table schemas (documents, bookmarks, settings)
│   ├── daos/                    # Data-access objects (queries per table)
│   └── database_providers.dart  # Riverpod providers exposing the DB/DAOs
│
├── pdf/                      # PDF domain/engine logic — the "business logic" layer
│   ├── engine/                  # pdfrx wrapper (pdf_engine.dart)
│   ├── manipulation/             # Merge/split/rotate/extract services
│   ├── ocr/                      # ML Kit OCR service
│   ├── signature/                # Signature rendering / background removal
│   ├── watermark/                # Watermark rendering
│   ├── cache/                    # LRU page/thumbnail caches
│   ├── models/                   # Plain PDF data models (e.g. pdf_document_info.dart)
│   ├── renderer/                 # Viewer config
│   └── pdf_providers.dart        # Riverpod providers wiring the above services
│
└── features/                 # One folder per screen/feature (MVVM triads)
    ├── library/                  # Home/library screen — list & import documents
    ├── viewer/                   # PDF viewer screen
    ├── settings/                 # Settings screen
    └── tools/                    # PDF tool screens, one subfolder each:
        ├── merge/  split/  rotate/  extract/
        ├── compress/  watermark/  sign/  scan/  ocr/
        └── domain/ (tool_run_state.dart) — shared tool state model
```

Each feature folder follows the same shape:

```
features/<name>/
├── domain/                   # Model: state classes (e.g. import_state.dart)
└── presentation/
    ├── <name>_screen.dart      # View: widgets/layout, reads providers, no business logic
    ├── providers/
    │   └── <name>_controller.dart  # ViewModel: Riverpod Notifier, holds state + actions
    └── widgets/               # Small widgets private to this feature
```

### Where to edit for common changes

| I want to... | Edit here |
|---|---|
| Change what a screen looks like | `features/<name>/presentation/<name>_screen.dart` or its `widgets/` |
| Change what happens when a button/action is tapped | `features/<name>/presentation/providers/<name>_controller.dart` |
| Add/change a PDF operation (merge, split, compress, etc.) | `pdf/manipulation/` (service) + the matching `features/tools/<tool>/` controller |
| Add a new PDF tool screen | new folder under `features/tools/<new_tool>/` (copy an existing tool's shape) |
| Change how documents are stored/queried | `database/tables/` and `database/daos/` |
| Add app-wide constants, formatters, or error types | `core/` |
| Change theme/colors/typography | `app/theme/` |
| Add/change a route or app-level navigation | `app/router.dart` |
| Change caching behavior (thumbnails/pages) | `pdf/cache/` |
