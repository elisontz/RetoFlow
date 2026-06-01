import Foundation

enum ExportConcurrencyMode: String, CaseIterable, Identifiable, Sendable {
    case auto
    case fixed6
    case fixed8
    case fixed10

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .auto: return String(localized: "自动")
        case .fixed6: return "6"
        case .fixed8: return "8"
        case .fixed10: return "10"
        }
    }

    nonisolated var targetConcurrency: Int? {
        switch self {
        case .auto: return nil
        case .fixed6: return 6
        case .fixed8: return 8
        case .fixed10: return 10
        }
    }
}
