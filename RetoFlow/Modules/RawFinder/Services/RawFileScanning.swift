import Foundation

struct RawFileScanning: Sendable {
    private let accessCoordinator: any SecurityScopedAccessing

    nonisolated init(accessCoordinator: any SecurityScopedAccessing = sharedSecurityScopedAccessCoordinator()) {
        self.accessCoordinator = accessCoordinator
    }

    nonisolated func scan(folders: [URL], supportedExtensions: Set<String>) async -> [URL] {
        await Task.detached(priority: .userInitiated) {
            var files: [URL] = []
            let fileManager = FileManager.default

            for folderURL in folders {
                accessCoordinator.withAccess(to: folderURL) {
                    if let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                        while let fileURL = enumerator.nextObject() as? URL {
                            if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                                files.append(fileURL)
                            }
                        }
                    }
                }
            }

            return Array(NSOrderedSet(array: files)).compactMap { $0 as? URL }
        }.value
    }
}
