import Foundation

enum SafeOperationReleaseCopy {
    nonisolated static var aboutSafetyOverview: String {
        String(localized: "所有批量文件操作都会先预检、默认跳过冲突，并在完成后生成任务摘要。")
    }
    nonisolated static var sharedTaskSummaryNotice: String {
        String(localized: "完成后会显示本次任务摘要，便于复核成功、跳过与失败项。")
    }

    nonisolated static var rawFinderSafetyNotice: String {
        String(localized: "替换前会先检查冲突，默认跳过重名目标。")
    }
    nonisolated static var rawFinderTrashNotice: String {
        String(localized: "确认后原小图会移到废纸篓，不会直接永久删除。")
    }
    nonisolated static var rawFinderConfirmationMessage: String {
        let body = String(localized: "此操作将使用匹配到的 RAW 文件替换原来的小图文件。\n\n替换前会先检查冲突，默认跳过重名目标。\n确认后原小图会移到废纸篓，不会直接永久删除。")
        return "\(body)\n\(sharedTaskSummaryNotice)"
    }

    nonisolated static var organizerSafetyNotice: String {
        String(localized: "整理前先预览匹配结果；整理时默认跳过冲突文件，不覆盖现有内容。")
    }
    nonisolated static var organizerMismatchNotice: String {
        String(localized: "未匹配文件会移动到未整理子目录，便于后续复核。")
    }
    nonisolated static var organizerConfirmationMessage: String {
        let body = String(localized: "此操作将重组待整理文件夹中的文件结构：\n\n1. 匹配的文件将被移动到与目标文件夹相同的相对路径下。\n2. 未匹配的文件将被移动到未整理子文件夹中。\n\n整理前会先预览匹配结果，执行时默认跳过冲突文件，不覆盖现有内容。")
        return "\(body)\n\(sharedTaskSummaryNotice)"
    }

    nonisolated static var renamerSafetyNotice: String {
        String(localized: "先预览后执行；遇到重名时默认跳过，不覆盖现有文件。")
    }
    nonisolated static var renamerPreviewNotice: String {
        String(localized: "规则修改后会先刷新预览，再决定是否执行。")
    }
    nonisolated static var exporterSafetyNotice: String {
        String(localized: "导出前请先选择输出位置；默认不会覆盖同名文件。")
    }
    nonisolated static var exporterSubfolderNotice: String {
        String(localized: "手动选择输出目录时，会在目标目录下创建\u{201C}原文件夹名_小图\u{201D}，并保留其内部层级结构。")
    }
}
