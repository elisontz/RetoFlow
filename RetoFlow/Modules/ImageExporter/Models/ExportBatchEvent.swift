import Foundation

struct ExportBatchDecision: Sendable {
    let concurrency: Int
    let reason: String
}

struct ExportBatchSummary: Sendable {
    let totalCount: Int
    let successCount: Int
    let failureCount: Int
    let skippedCount: Int
    let targetConcurrency: Int
    let concurrencyReason: String
    let outputDirectorySummary: String
    let wasCancelled: Bool
    let startedAt: Date
    let endedAt: Date
    let records: [OperationRecord]

    nonisolated init(
        totalCount: Int,
        successCount: Int,
        failureCount: Int,
        skippedCount: Int = 0,
        targetConcurrency: Int,
        concurrencyReason: String,
        outputDirectorySummary: String = "",
        wasCancelled: Bool,
        startedAt: Date = .distantPast,
        endedAt: Date = .distantPast,
        records: [OperationRecord] = []
    ) {
        self.totalCount = totalCount
        self.successCount = successCount
        self.failureCount = failureCount
        self.skippedCount = skippedCount
        self.targetConcurrency = targetConcurrency
        self.concurrencyReason = concurrencyReason
        self.outputDirectorySummary = outputDirectorySummary
        self.wasCancelled = wasCancelled
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.records = records
    }
}

enum ExportBatchEvent: Sendable {
    case started(index: Int, fileName: String)
    case completed(index: Int, result: ExportResult, elapsed: TimeInterval)
    case progress(completedCount: Int, totalCount: Int)
    case finished(summary: ExportBatchSummary)
}

extension TaskReport {
    /// 从批量导出摘要构建任务报告，定义在 ImageExporter 模块内以避免 Shared 层依赖具体业务类型
    nonisolated init(summary: ExportBatchSummary) {
        self.init(
            taskKind: "image-exporter",
            startedAt: summary.startedAt,
            endedAt: summary.endedAt,
            successCount: summary.successCount,
            skippedCount: summary.skippedCount,
            failedCount: summary.failureCount,
            records: summary.records
        )
    }
}
