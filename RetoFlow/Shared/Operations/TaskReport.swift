import Foundation

struct TaskReport: Sendable {
    nonisolated let taskKind: String
    nonisolated let startedAt: Date
    nonisolated let endedAt: Date
    nonisolated let successCount: Int
    nonisolated let skippedCount: Int
    nonisolated let failedCount: Int
    nonisolated let records: [OperationRecord]

    nonisolated init(
        taskKind: String,
        startedAt: Date,
        endedAt: Date,
        successCount: Int,
        skippedCount: Int,
        failedCount: Int,
        records: [OperationRecord]
    ) {
        self.taskKind = taskKind
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.successCount = successCount
        self.skippedCount = skippedCount
        self.failedCount = failedCount
        self.records = records
    }
}

// MARK: - Codable
// 项目启用了 -default-isolation=MainActor，自动合成的 Codable 会被推断为 @MainActor 隔离，
// 导致在 nonisolated 上下文（如 TaskReportStore）中无法使用。
// 因此手动实现 Codable 并显式标注 nonisolated，确保可在任意上下文编解码。
extension TaskReport: Codable {
    private enum CodingKeys: String, CodingKey {
        case taskKind, startedAt, endedAt, successCount, skippedCount, failedCount, records
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        taskKind     = try c.decode(String.self,            forKey: .taskKind)
        startedAt    = try c.decode(Date.self,              forKey: .startedAt)
        endedAt      = try c.decode(Date.self,              forKey: .endedAt)
        successCount = try c.decode(Int.self,               forKey: .successCount)
        skippedCount = try c.decode(Int.self,               forKey: .skippedCount)
        failedCount  = try c.decode(Int.self,               forKey: .failedCount)
        records      = try c.decode([OperationRecord].self, forKey: .records)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(taskKind,     forKey: .taskKind)
        try c.encode(startedAt,    forKey: .startedAt)
        try c.encode(endedAt,      forKey: .endedAt)
        try c.encode(successCount, forKey: .successCount)
        try c.encode(skippedCount, forKey: .skippedCount)
        try c.encode(failedCount,  forKey: .failedCount)
        try c.encode(records,      forKey: .records)
    }
}
