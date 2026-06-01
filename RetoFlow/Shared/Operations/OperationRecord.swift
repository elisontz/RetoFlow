import Foundation

enum OperationExecutionStatus: String, Codable, Sendable {
    case succeeded
    case skipped
    case failed
}

struct OperationRecord: Codable, Sendable, Equatable {
    nonisolated let operationID: UUID
    nonisolated let kind: PlannedOperationKind
    nonisolated let sourceURL: URL
    nonisolated let destinationURL: URL?
    nonisolated let status: OperationExecutionStatus
    nonisolated let errorDescription: String?
}
