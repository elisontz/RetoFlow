# RetoFlow

[English](#english) | [简体中文](#简体中文)

---

## English

RetoFlow is a native macOS app for photographers and editors who need to clean up folders, match RAW files, rename batches, and export compressed JPEGs without turning the job into a spreadsheet.

It is built for the small, repetitive tasks that show up after a shoot: finding the RAW file behind a selected JPEG, putting edited images back into the same folder structure as the originals, previewing a batch rename before touching disk, and exporting images with predictable size and quality settings.

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

## Contributing

Issues and pull requests are welcome. If you want to contribute, a good first step is to open an issue with:

- the workflow you are trying to improve;
- sample folder shapes or filenames, if relevant;
- what you expected RetoFlow to do;
- what happened instead.

For code changes, please keep the scope focused and include tests for file operations, matching rules, rename previews, or export behavior when applicable.

## License

RetoFlow is released under the [MIT License](LICENSE).

[Back to top](#retoflow)

---

## 简体中文

RetoFlow 是一个 macOS 原生摄影后期工具，用来处理那些拍摄后常见但很容易耗时间的文件工作：匹配 RAW 文件、整理修图目录、批量重命名，以及导出压缩 JPEG。

它不是大而全的图片管理软件，更像一个安静的小工具箱。你可以从 Finder 选择文件或文件夹，先看清楚将要发生什么，再执行批量操作，最后得到任务报告。

## 功能

| 工具 | 说明 |
| --- | --- |
| 找到 RAW 文件 | 扫描选中的文件夹，按文件名匹配 JPEG/HEIC 与对应 RAW 文件。匹配到的 RAW 可以复制，也可以用来替换已选小图。 |
| 目录结构整理 | 对比修图文件夹和原始文件夹，将修好的图片移动到对应的目录结构中。 |
| 文件重命名 | 真正改名之前先生成预览。支持文本替换、正则表达式、前后缀、序列号和大小写转换。 |
| 图片导出压缩 | 批量导出 JPEG，支持尺寸限制、目标体积、元数据选项、覆盖保护、进度反馈和自动并发策略。 |

## 为什么做 RetoFlow

很多摄影工具要么太重，要么对这些中间环节不够顺手。RetoFlow 只盯住几个明确场景：

- 从 Finder 选择文件或文件夹；
- 文件操作前先预览结果；
- 默认避免覆盖已有文件；
- 批量任务完成后保留报告；
- 遵守 macOS 沙盒文件访问规则。

## 系统要求

- macOS 15.6 或更高版本
- 建议使用 Xcode 17 或更高版本
- Apple Silicon 或 Intel Mac

## 从源码构建

克隆仓库并打开 Xcode 项目：

```bash
git clone <repo-url>
cd RetoFlow
open RetoFlow.xcodeproj
```

命令行构建：

```bash
xcodebuild -scheme RetoFlow -destination 'platform=macOS' build
```

运行测试：

```bash
xcodebuild -scheme RetoFlow -destination 'platform=macOS' test
```

## 项目结构

```text
RetoFlow/
├── App/                        # 应用入口与主导航
├── Modules/
│   ├── RawFinder/              # RAW/JPEG 匹配流程
│   ├── EditedImageOrganizer/   # 目录结构整理流程
│   ├── FileRenamer/            # 批量重命名流程
│   ├── ImageExporter/          # JPEG 导出与压缩流程
│   ├── Settings/
│   └── About/
├── Shared/
│   ├── Operations/             # 计划、预检、执行与报告
│   ├── FileAccess/             # 安全作用域文件访问
│   └── Support/                # 共享 UI 与平台辅助代码
├── RetoFlowTests/
└── RetoFlowUITests/
```

## 架构

RetoFlow 使用 SwiftUI 搭建应用外壳和功能界面，在需要 macOS 原生能力的地方少量使用 AppKit，例如打开文件面板、在 Finder 中定位文件、剪贴板访问和应用激活。

文件操作流程大致遵循：

```text
View -> ViewModel -> Use Case -> OperationPlan -> Preflight -> Execution -> TaskReport
```

共享操作层的设计比较保守：

- `OperationPlan` 在真正执行前描述文件操作。
- `OperationPreflightService` 检查源文件缺失、目标冲突和写入权限。
- `TaskExecutionCenter` 执行可运行操作，并记录跳过或失败的项目。
- `SecurityScopedAccessCoordinator` 让文件访问符合 macOS 沙盒规则。

## 技术栈

- SwiftUI 和 AppKit
- Swift 6
- Core Image 和 ImageIO
- App Sandbox 与用户选择文件的读写权限
- XCTest

## 参与贡献

欢迎提交 issue 和 pull request。反馈问题时，最好说明：

- 你想改善的工作流；
- 相关的文件夹结构或文件名示例；
- 你期待 RetoFlow 做什么；
- 实际发生了什么。

如果提交代码，请尽量保持改动聚焦。涉及文件操作、匹配规则、重命名预览或导出行为时，请补上对应测试。

## 许可证

RetoFlow 基于 [MIT License](LICENSE) 开源。

[回到顶部](#retoflow)
