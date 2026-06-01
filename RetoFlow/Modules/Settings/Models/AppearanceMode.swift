import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return String(localized: "自动")
        case .light: return String(localized: "浅色")
        case .dark: return String(localized: "深色")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .system:
            return LinearGradient(
                colors: [Color.blue.opacity(0.9), Color.indigo.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .light:
            return LinearGradient(
                colors: [Color.cyan.opacity(0.8), Color.blue.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dark:
            return LinearGradient(
                colors: [Color.indigo.opacity(0.7), Color.black.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
