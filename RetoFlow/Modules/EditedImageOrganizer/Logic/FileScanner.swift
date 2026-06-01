import Foundation

class FileScanner {
    static func scan(folder url: URL) async -> [ImageFile] {
        do {
            return try await EditedImageFileScanning().scan(folder: url)
        } catch {
            return []
        }
    }
}
