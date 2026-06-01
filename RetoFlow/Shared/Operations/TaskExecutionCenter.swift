import Foundation

struct TaskExecutionCenter: Sendable {
    nonisolated private let fileAccessCoordinator: any FileAccessCoordinating
    nonisolated private let accessCoordinator: any SecurityScopedAccessing
    nonisolated private let now: @Sendable () -> Date

    nonisolated init(
        fileAccessCoordinator: FileAccessCoordinating = FileAccessCoordinator(),
        accessCoordinator: any SecurityScopedAccessing = sharedSecurityScopedAccessCoordinator(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fileAccessCoordinator = fileAccessCoordinator
        self.accessCoordinator = accessCoordinator
        self.now = now
    }

    nonisolated func execute(plan: OperationPlan, preflightResults: [UUID: PreflightStatus]) async -> TaskReport {
        let startedAt = now()
        var records: [OperationRecord] = []
        var successCount = 0
        var skippedCount = 0
        var failedCount = 0

        for operation in plan.operations {
            let preflightStatus = preflightResults[operation.id] ?? .blocked([])

            switch preflightStatus {
            case .blocked:
                skippedCount += 1
                records.append(
                    OperationRecord(
                        operationID: operation.id,
                        kind: operation.kind,
                        sourceURL: operation.sourceURL,
                        destinationURL: operation.destinationURL,
                        status: .skipped,
                        errorDescription: description(for: preflightStatus)
                    )
                )
                continue
            case .ready, .warning:
                break
            }

            do {
                try execute(operation)
                successCount += 1
                records.append(
                    OperationRecord(
                        operationID: operation.id,
                        kind: operation.kind,
                        sourceURL: operation.sourceURL,
                        destinationURL: operation.destinationURL,
                        status: .succeeded,
                        errorDescription: nil
                    )
                )
            } catch {
                failedCount += 1
                records.append(
                    OperationRecord(
                        operationID: operation.id,
                        kind: operation.kind,
                        sourceURL: operation.sourceURL,
                        destinationURL: operation.destinationURL,
                        status: .failed,
                        errorDescription: error.localizedDescription
                    )
                )
            }
        }

        return TaskReport(
            taskKind: plan.taskKind,
            startedAt: startedAt,
            endedAt: now(),
            successCount: successCount,
            skippedCount: skippedCount,
            failedCount: failedCount,
            records: records
        )
    }

    nonisolated private func execute(_ operation: PlannedOperation) throws {
        try accessCoordinator.withAccess(
            to: [operation.sourceURL, operation.destinationURL].compactMap { $0 }
        ) {
            switch operation.kind {
            case .rename:
                if let destinationURL = operation.destinationURL {
                    try fileAccessCoordinator.ensureDirectoryExists(at: destinationURL.deletingLastPathComponent())
                    try fileAccessCoordinator.renameItem(at: operation.sourceURL, to: destinationURL)
                }
            case .move:
                if let destinationURL = operation.destinationURL {
                    try fileAccessCoordinator.ensureDirectoryExists(at: destinationURL.deletingLastPathComponent())
                    try fileAccessCoordinator.moveItem(at: operation.sourceURL, to: destinationURL)
                }
            case .copy, .exportJPEG:
                if let destinationURL = operation.destinationURL {
                    try fileAccessCoordinator.ensureDirectoryExists(at: destinationURL.deletingLastPathComponent())
                    try fileAccessCoordinator.copyItem(at: operation.sourceURL, to: destinationURL)
                }
            case .trash:
                try fileAccessCoordinator.trashItem(at: operation.sourceURL)
            }
        }
    }

    nonisolated private func description(for status: PreflightStatus) -> String? {
        switch status {
        case .ready:
            return nil
        case .warning(let issues), .blocked(let issues):
            return issues.map(\.localizedDescription).joined(separator: "\n")
        }
    }
}
