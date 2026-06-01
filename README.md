# RetoFlow

RetoFlow is a native macOS app for photographers and editors who need to clean up folders, match RAW files, rename batches, and export compressed JPEGs without turning the job into a spreadsheet.

It is built for the small, repetitive tasks that show up after a shoot: finding the RAW file behind a selected JPEG, putting edited images back into the same folder structure as the originals, previewing a batch rename before touching disk, and exporting images with predictable size and quality settings.

> Primary language: English. A Chinese overview is available below.

## Features

| Tool | What it does |
| --- | --- |
| RAW Finder | Scans selected folders and matches JPEG/HEIC files with RAW files by filename. Matched RAW files can be copied or used to replace selected small images. |
| Edited Image Organizer | Compares an edited-image folder with an original folder and moves files into the matching directory structure. |
| File Renamer | Builds a preview before renaming files. Rules include replace, regular expressions, prefix/suffix, sequences, and case conversion. |
| Image Exporter | Exports images as JPEG with dimension limits, file-size targets, metadata options, overwrite protection, progress reporting, and a hardware-aware concurrency setting. |

## Why RetoFlow Exists

Most photo utilities are either too broad or too manual for these in-between jobs. RetoFlow keeps the workflow narrow:

- choose files or folders from Finder;
- review what will happen before file operations run;
- avoid overwriting existing files by default;
- keep a per-task report after batch operations;
- stay inside the macOS sandbox file-access model.

## Requirements

- macOS 15.6 or later
- Xcode 17 or later recommended
- Apple Silicon or Intel Mac

## Build From Source

Clone the repository and open the Xcode project:

```bash
git clone <repo-url>
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

- `OperationPlan` describes the file operations before they run.
- `OperationPreflightService` checks missing sources, destination conflicts, and write access.
- `TaskExecutionCenter` executes ready operations and records skipped or failed items.
- `SecurityScopedAccessCoordinator` keeps file access aligned with macOS sandbox rules.

## Tech Stack

- SwiftUI and AppKit
- Swift 6
- Core Image and ImageIO for image processing
- App Sandbox with user-selected read/write file access
- XCTest for unit and integration coverage

## Development Notes

- The app is designed around local files. Network services are not part of the core workflow.
- Destructive operations should be previewable, skip existing destinations by default, and report what happened.
- Feature code is grouped by module; shared behavior lives under `Shared/`.
- Keep file-operation logic testable outside of SwiftUI views.

## Contributing

Issues and pull requests are welcome. If you want to contribute, a good first step is to open an issue with:

- the workflow you are trying to improve;
- sample folder shapes or filenames, if relevant;
- what you expected RetoFlow to do;
- what happened instead.

For code changes, please keep the scope focused and include tests for file operations, matching rules, rename previews, or export behavior when applicable.

## License

This repository does not include an open-source license yet. Add a `LICENSE` file before publishing the project publicly on GitHub so users know what they are allowed to do with the code.

---

## 中文简介

RetoFlow 是一个面向摄影后期工作流的 macOS 原生工具，主要处理拍摄后那些重复但容易出错的文件任务：匹配 RAW 文件、整理修图目录、批量重命名，以及导出压缩 JPEG。

### 功能

| 模块 | 说明 |
| --- | --- |
| 找到 RAW 文件 | 扫描文件夹，按文件名匹配 JPEG/HEIC 与对应 RAW 文件，并支持复制或替换操作。 |
| 目录结构整理 | 将待整理的修图文件移动到与原始目录一致的层级中。 |
| 文件重命名 | 在真正改名之前生成预览，支持替换、正则、前后缀、序列号和大小写转换。 |
| 图片导出压缩 | 批量导出 JPEG，支持尺寸限制、目标体积、元数据保留、覆盖保护、进度反馈和自动并发策略。 |

### 设计取向

RetoFlow 不追求成为一个大而全的图片管理软件。它更像是后期工作流里的小工具箱：每个功能都围绕一个明确场景，先预览，再执行，最后给出任务报告。文件访问遵守 macOS 沙盒机制，默认避免覆盖已有文件。

### 本地构建

```bash
git clone <repo-url>
cd RetoFlow
open RetoFlow.xcodeproj
```

命令行构建和测试：

```bash
xcodebuild -scheme RetoFlow -destination 'platform=macOS' build
xcodebuild -scheme RetoFlow -destination 'platform=macOS' test
```

### 开源前提醒

当前仓库还没有正式的开源许可证。发布到 GitHub 前建议补上 `LICENSE` 文件，比如 MIT、Apache-2.0、GPL 等，具体取决于你希望别人如何使用和分发代码。
