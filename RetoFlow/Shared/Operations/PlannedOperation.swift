import Foundation

struct PlannedOperation: Identifiable, Equatable, Codable, Sendable {
    nonisolated let id: UUID
    nonisolated let kind: PlannedOperationKind
    nonisolated let sourceURL: URL
    nonisolated let destinationURL: URL?
    nonisolated let riskLevel: OperationRiskLevel
    nonisolated let recoverability: RecoverabilityLevel

    nonisolated init(
        id: UUID = UUID(),
        kind: PlannedOperationKind,
        sourceURL: URL,
        destinationURL: URL?,
        riskLevel: OperationRiskLevel,
        recoverability: RecoverabilityLevel
    ) {
        self.id = id
        self.kind = kind
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.riskLevel = riskLevel
        self.recoverability = recoverability
    }
}
