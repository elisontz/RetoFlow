import Foundation

struct TaskReportPresentation: Sendable {
    let message: String
    let debugSummary: String

    nonisolated init(report: TaskReport) {
        let destinationDirectories = Set(
            report.records.compactMap { $0.destinationURL?.deletingLastPathComponent().path }
        )
        let destinationSummary = destinationDirectories.sorted().first
        var lines = [
            String(localized: "成功: \(report.successCount)"),
            String(localized: "跳过: \(report.skippedCount)"),
            String(localized: "失败: \(report.failedCount)")
        ]
        if let destinationSummary {
            lines.append(String(localized: "目标: \(destinationSummary)"))
        }

        self.message = lines.joined(separator: "\n")
        self.debugSummary = "\(report.taskKind): success=\(report.successCount), skipped=\(report.skippedCount), failed=\(report.failedCount)"
    }
}
