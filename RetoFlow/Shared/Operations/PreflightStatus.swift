import Foundation

enum PreflightStatus: Codable, Sendable {
    case ready
    case warning([PreflightIssue])
    case blocked([PreflightIssue])
}

extension PreflightStatus: Equatable {
    nonisolated static func == (lhs: PreflightStatus, rhs: PreflightStatus) -> Bool {
        switch (lhs, rhs) {
        case (.ready, .ready):
            return true
        case (.warning(let left), .warning(let right)):
            return left == right
        case (.blocked(let left), .blocked(let right)):
            return left == right
        default:
            return false
        }
    }
}
