import Foundation

struct RawMatchPair: Identifiable, Equatable, Sendable {
    let id = UUID()
    let imageURL: URL
    var rawURL: URL?
    
    nonisolated var imageName: String {
        imageURL.lastPathComponent
    }
    
    nonisolated var rawName: String {
        rawURL?.lastPathComponent ?? ""
    }
    
    nonisolated var status: MatchStatus {
        if rawURL != nil {
            return .matched
        } else {
            return .missing
        }
    }
}

nonisolated enum MatchStatus: Hashable, Sendable {
    case matched
    case missing
    
    nonisolated var iconName: String {
        switch self {
        case .matched: return "checkmark.circle.fill"
        case .missing: return "exclamationmark.triangle.fill"
        }
    }
}

enum RawFinderError: LocalizedError, AppPresentableError {
    case copyOperationFailed(failures: Int)

    var errorDescription: String? {
        switch self {
        case .copyOperationFailed(let failures):
            return String(localized: "复制操作失败: \(failures) 个文件")
        }
    }
}
