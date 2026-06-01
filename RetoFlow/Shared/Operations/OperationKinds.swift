import Foundation

enum PlannedOperationKind: String, CaseIterable, Codable, Sendable {
    case rename
    case move
    case copy
    case trash
    case exportJPEG
}

enum OperationRiskLevel: String, CaseIterable, Codable, Sendable {
    case low
    case medium
    case high
}

enum RecoverabilityLevel: String, CaseIterable, Codable, Sendable {
    case reversible
    case userRecoverable
    case reproducible
    case irreversible
}
