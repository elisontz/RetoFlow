# RetoFlow

[English](README.md) | **简体中文**

面向摄影后期文件整理的 macOS 原生工具：匹配 RAW、整理目录、批量重命名、导出压缩 JPEG。

## 概览

RetoFlow 是一个 macOS 原生应用，适合摄影师和修图工作者处理拍摄后的文件整理工作。

它专注于几个常见但容易耗时间的环节：

- 从已选 JPEG 或 HEIC 找到对应 RAW 文件；
- 将修好的图片放回与原始文件一致的目录结构；
- 在真正改名前预览批量重命名规则；
- 按可控的尺寸、体积、元数据和覆盖策略导出 JPEG。

## 功能

| 工具 | 说明 |
| --- | --- |
| 找到 RAW 文件 | 扫描选中的文件夹，按文件名匹配 JPEG/HEIC 与对应 RAW 文件。匹配到的 RAW 可以复制，也可以用来替换已选小图。 |
| 目录结构整理 | 对比修图文件夹和原始文件夹，将修好的图片移动到对应的目录结构中。 |
| 文件重命名 | 真正改名之前先生成预览。支持文本替换、正则表达式、前后缀、序列号和大小写转换。 |
| 图片导出压缩 | 批量导出 JPEG，支持尺寸限制、目标体积、元数据选项、覆盖保护、进度反馈和自动并发策略。 |

## 设计原则

- 文件操作执行前应该能看清楚结果。
- 默认不应意外覆盖已有文件。
- 批量任务完成后应该有清晰的结果报告。
- 文件访问遵守 macOS 沙盒规则。
- 每个工具只解决一个明确的后期工作流问题。

## 系统要求

- macOS 15.6 或更高版本
- 建议使用 Xcode 17 或更高版本
- Apple Silicon 或 Intel Mac

## 从源码构建

克隆仓库并打开 Xcode 项目：

```bash
git clone https://github.com/elisontz/RetoFlow.git
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
