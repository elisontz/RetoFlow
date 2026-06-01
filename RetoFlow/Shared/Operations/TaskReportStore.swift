import Foundation

struct TaskReportStore: Sendable {
    nonisolated private let baseDirectory: URL

    nonisolated init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.baseDirectory = appSupport
                .appendingPathComponent("RetoFlow", isDirectory: true)
                .appendingPathComponent("TaskReports", isDirectory: true)
        }
    }

    nonisolated func save(_ report: TaskReport) throws -> URL {
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        let fileURL = uniqueFileURL(for: report)
        try data.write(to: fileURL)
        return fileURL
    }

    nonisolated private func uniqueFileURL(for report: TaskReport) -> URL {
        let baseName = "\(report.taskKind)-\(Int(report.endedAt.timeIntervalSince1970))"
        var candidate = baseDirectory.appendingPathComponent(baseName).appendingPathExtension("json")
        var suffix = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = baseDirectory
                .appendingPathComponent("\(baseName)-\(suffix)")
                .appendingPathExtension("json")
            suffix += 1
        }

        return candidate
    }
}
