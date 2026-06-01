# RetoFlow

**English** | [简体中文](README.zh-CN.md)

Native macOS tools for photo workflow cleanup: RAW matching, folder organization, batch renaming, and JPEG export.

## Overview

RetoFlow is a native macOS app for photographers and editors who need to clean up folders after a shoot without turning the job into a spreadsheet.

It focuses on a few practical tasks that usually sit between selection and final delivery:

- finding the RAW file behind a selected JPEG or HEIC;
- putting edited images back into the same folder structure as the originals;
- previewing batch rename rules before touching files;
- exporting JPEGs with predictable size, quality, metadata, and overwrite behavior.

## Features

| Tool | What it does |
| --- | --- |
| RAW Finder | Scans selected folders and matches JPEG/HEIC files with RAW files by filename. Matched RAW files can be copied or used to replace selected small images. |
| Edited Image Organizer | Compares an edited-image folder with an original folder and moves files into the matching directory structure. |
| File Renamer | Builds a preview before renaming files. Rules include replace, regular expressions, prefix/suffix, sequences, and case conversion. |
| Image Exporter | Exports images as JPEG with dimension limits, file-size targets, metadata options, overwrite protection, progress reporting, and a hardware-aware concurrency setting. |

## Design Principles

- File operations should be visible before they run.
- Existing files should not be overwritten by surprise.
- Batch tasks should produce a clear result report.
- macOS sandbox file access should be respected instead of bypassed.
- Each tool should stay focused on a real post-production workflow.

## Requirements

- macOS 15.6 or later
- Xcode 17 or later recommended
- Apple Silicon or Intel Mac

## Build From Source

Clone the repository and open the Xcode project:

```bash
git clone https://github.com/elisontz/RetoFlow.git
cd RetoFlow
open RetoFlow.xcodeproj
```

Build from the command line:

```bash
xcodebuild -scheme RetoFlow -destination 'platform=macOS' build
```

Run tests:

```bash
xcodebuild -scheme RetoFlow -destination 'platform=macOS' test
```

## Project Structure

```text
RetoFlow/
├── App/                        # App entry point and root navigation
├── Modules/
│   ├── RawFinder/              # RAW/JPEG matching workflow
│   ├── EditedImageOrganizer/   # Folder-structure organization workflow
│   ├── FileRenamer/            # Batch rename workflow
│   ├── ImageExporter/          # JPEG export and compression workflow
│   ├── Settings/
│   └── About/
├── Shared/
│   ├── Operations/             # Plan, preflight, execution, and reports
│   ├── FileAccess/             # Security-scoped file access
│   └── Support/                # Shared UI and platform helpers
├── RetoFlowTests/
└── RetoFlowUITests/
```

## Architecture

RetoFlow uses SwiftUI for the app shell and feature views, with small AppKit bridges where macOS-specific behavior is needed, such as open panels, Finder reveal actions, pasteboard access, and app activation.

File-operation workflows generally follow this shape:

```text
View -> ViewModel -> Use Case -> OperationPlan -> Preflight -> Execution -> TaskReport
```

The shared operation layer is intentionally conservative:

- `OperationPlan` describes file operations before they run.
- `OperationPreflightService` checks missing sources, destination conflicts, and write access.
- `TaskExecutionCenter` executes ready operations and records skipped or failed items.
- `SecurityScopedAccessCoordinator` keeps file access aligned with macOS sandbox rules.

## Tech Stack

- SwiftUI and AppKit
- Swift 6
- Core Image and ImageIO
- App Sandbox with user-selected read/write file access
- XCTest

## Contributing

Issues and pull requests are welcome. If you want to contribute, a good first step is to open an issue with:

- the workflow you are trying to improve;
- sample folder shapes or filenames, if relevant;
- what you expected RetoFlow to do;
- what happened instead.

For code changes, please keep the scope focused. Add tests for file operations, matching rules, rename previews, or export behavior when applicable.

## License

RetoFlow is released under the [MIT License](LICENSE).
