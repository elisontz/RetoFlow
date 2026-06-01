import Foundation

enum ImageExportCopy {
    nonisolated static var emptySelectionAlert: String { String(localized: "请先选择要导出的图片") }
    nonisolated static var invalidConfigAlert: String { String(localized: "配置无效") }
    nonisolated static func cancelledAlert(success: Int, failure: Int, unfinished: Int) -> String {
        String(localized: "导出已取消。\n成功: \(success) 个\n失败: \(failure) 个\n未完成: \(unfinished) 个")
    }
    nonisolated static func successAlert(count: Int) -> String {
        String(localized: "导出完成！\n成功: \(count) 个文件")
    }
    nonisolated static func mixedAlert(success: Int, failure: Int) -> String {
        String(localized: "导出完成。\n成功: \(success) 个\n失败: \(failure) 个")
    }
    nonisolated static func cancelledDebug(success: Int, failure: Int, unfinished: Int) -> String {
        "导出取消: success=\(success), fail=\(failure), unfinished=\(unfinished)"
    }
    nonisolated static func successDebug(success: Int) -> String {
        "导出结束: success=\(success), fail=0"
    }
    nonisolated static func mixedDebug(success: Int, failure: Int) -> String {
        "导出结束: success=\(success), fail=\(failure)"
    }
}

struct ImageExportPresentationMapper: Sendable {
    nonisolated init() {}

    nonisolated func makeValidationFailurePresentation(_ validationResult: ValidationResult) -> ExportAlertPresentation {
        ExportAlertPresentation(
            message: validationResult.errorMessage ?? ImageExportCopy.invalidConfigAlert
        )
    }

    nonisolated func makeEmptySelectionPresentation() -> ExportAlertPresentation {
        ExportAlertPresentation(message: ImageExportCopy.emptySelectionAlert)
    }

    nonisolated func makeCompletionPresentation(
        summary: ExportBatchSummary,
        unfinishedCount: Int
    ) -> ExportCompletionPresentation {
        if summary.wasCancelled {
            return ExportCompletionPresentation(
                alertMessage: ImageExportCopy.cancelledAlert(
                    success: summary.successCount,
                    failure: summary.failureCount,
                    unfinished: unfinishedCount
                ),
                debugSummary: ImageExportCopy.cancelledDebug(
                    success: summary.successCount,
                    failure: summary.failureCount,
                    unfinished: unfinishedCount
                )
            )
        }

        if summary.failureCount == 0 {
            return ExportCompletionPresentation(
                alertMessage: ImageExportCopy.successAlert(count: summary.successCount),
                debugSummary: ImageExportCopy.successDebug(success: summary.successCount)
            )
        }

        return ExportCompletionPresentation(
            alertMessage: ImageExportCopy.mixedAlert(
                success: summary.successCount,
                failure: summary.failureCount
            ),
            debugSummary: ImageExportCopy.mixedDebug(
                success: summary.successCount,
                failure: summary.failureCount
            )
        )
    }
}
