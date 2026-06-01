import Foundation

enum AppModule: String, CaseIterable, Identifiable {
    case rawFinder
    case organizer
    case renamer
    case exporter
    case settings
    case about
    case help

    static var navigationCases: [AppModule] {
        [.rawFinder, .organizer, .renamer, .exporter]
    }
    
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rawFinder: return String(localized: "找到RAW文件")
        case .organizer: return String(localized: "目录结构整理")
        case .renamer: return String(localized: "文件重命名")
        case .exporter: return String(localized: "图片导出压缩")
        case .settings: return String(localized: "设置")
        case .about: return String(localized: "关于")
        case .help: return String(localized: "使用手册")
        }
    }
    
    var icon: String {
        switch self {
        case .rawFinder: return "camera.viewfinder"
        case .organizer: return "folder.badge.gearshape"
        case .renamer: return "character.cursor.ibeam"
        case .exporter: return "arrow.down.doc"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        case .help: return "book.closed"
        }
    }
}
