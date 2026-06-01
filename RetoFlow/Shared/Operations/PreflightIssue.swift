import Foundation

enum PreflightIssue: Codable, Sendable {
    case sourceMissing(URL)
    case destinationExists(URL)
    case destinationNotWritable(URL)
}

extension PreflightIssue: Equatable {
    nonisolated static func == (lhs: PreflightIssue, rhs: PreflightIssue) -> Bool {
        switch (lhs, rhs) {
        case (.sourceMissing(let left), .sourceMissing(let right)):
            return left == right
        case (.destinationExists(let left), .destinationExists(let right)):
            return left == right
        case (.destinationNotWritable(let left), .destinationNotWritable(let right)):
            return left == right
        default:
            return false
        }
    }
}

extension PreflightIssue {
    /// 统一的用户可见描述，供所有模块复用，避免重复的 switch 逻辑。
    nonisolated var localizedDescription: String {
        switch self {
        case .sourceMissing(let url):
            return String(localized: "源文件不存在: \(url.lastPathComponent)")
        case .destinationExists(let url):
            return String(localized: "目标文件已存在: \(url.lastPathComponent)")
        case .destinationNotWritable(let url):
            return String(localized: "目标目录不可写: \(url.path)")
        }
    }
}
