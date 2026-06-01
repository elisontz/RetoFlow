import Foundation

enum EditedImageOrganizerError: LocalizedError, Equatable, AppPresentableError {
    case pathNotFound(URL)
    case notDirectory(URL)
    case createDirectoryFailed(URL)
    case moveFailed(source: URL, destination: URL)

    var errorDescription: String? {
        switch self {
        case .pathNotFound(let url):
            return String(localized: "路径不存在: \(url.path)")
        case .notDirectory(let url):
            return String(localized: "不是文件夹: \(url.path)")
        case .createDirectoryFailed(let url):
            return String(localized: "无法创建目录: \(url.path)")
        case .moveFailed(let source, let destination):
            return String(localized: "无法移动文件: \(source.lastPathComponent) -> \(destination.path)")
        }
    }
}
