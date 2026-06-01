import Foundation

struct EditedImageFileScanning: Sendable {
    private let accessCoordinator: any SecurityScopedAccessing

    nonisolated init(accessCoordinator: any SecurityScopedAccessing = sharedSecurityScopedAccessCoordinator()) {
        self.accessCoordinator = accessCoordinator
    }

    nonisolated func scan(folder url: URL) async throws -> [ImageFile] {
        try validateDirectory(url)

        return await Task.detached(priority: .userInitiated) {
            accessCoordinator.withAccess(to: url) {
                var images: [ImageFile] = []
                let fileManager = FileManager.default
                let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]

                if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: options) {
                    while let fileURL = enumerator.nextObject() as? URL {
                        do {
                            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                            if resourceValues.isRegularFile == true, Self.isImageFile(fileURL) {
                                images.append(ImageFile(filename: fileURL.lastPathComponent, url: fileURL))
                            }
                        } catch {
                            continue
                        }
                    }
                }

                return images
            }
        }.value
    }

    nonisolated func validateDirectory(_ url: URL) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        let exists = accessCoordinator.withAccess(to: url) {
            fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        }
        guard exists else {
            throw EditedImageOrganizerError.pathNotFound(url)
        }
        guard isDirectory.boolValue else {
            throw EditedImageOrganizerError.notDirectory(url)
        }
    }

    nonisolated private static func isImageFile(_ url: URL) -> Bool {
        let supportedExtensions: Set<String> = [
            "jpg", "jpeg", "png", "heic", "webp", "gif", "svg", "bmp", "tiff", "tif"
        ]
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }
}
