import Foundation

struct BuildExportImageListUseCase: Sendable {
    private let supportedExtensions: Set<String>
    private let accessCoordinator: any SecurityScopedAccessing

    nonisolated init(
        supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "tif", "tiff", "psd"],
        accessCoordinator: any SecurityScopedAccessing = sharedSecurityScopedAccessCoordinator()
    ) {
        self.supportedExtensions = supportedExtensions
        self.accessCoordinator = accessCoordinator
    }

    nonisolated func execute(
        sources: ImportedExportSources,
        existingImages: [ExportableImage],
        existingFolders: [URL],
        existingDirectFiles: [URL],
        importedRootFolders: Set<URL>
    ) -> BuildExportImageListResult {
        var images = existingImages
        var folders = existingFolders
        var directFiles = existingDirectFiles
        var rootFolders = importedRootFolders
        var knownImagePaths = Set(existingImages.map { normalizedPath(for: $0.url) })
        var knownFolderPaths = Set(existingFolders.map(normalizedPath(for:)))
        var knownDirectFilePaths = Set(existingDirectFiles.map(normalizedPath(for:)))

        for folder in sources.candidateFolders {
            let normalizedFolderPath = normalizedPath(for: folder)
            if !knownFolderPaths.contains(normalizedFolderPath) {
                folders.append(folder)
                knownFolderPaths.insert(normalizedFolderPath)
            }
        }

        for folder in sources.candidateFolders {
            rootFolders.insert(folder)

            for fileURL in scanSupportedFiles(in: folder) {
                let normalizedFilePath = normalizedPath(for: fileURL)
                guard !knownImagePaths.contains(normalizedFilePath) else { continue }
                images.append(ExportableImage(url: fileURL))
                knownImagePaths.insert(normalizedFilePath)
            }
        }

        for fileURL in sources.candidateFiles where isSupportedFile(fileURL) {
            let normalizedFilePath = normalizedPath(for: fileURL)

            if !knownDirectFilePaths.contains(normalizedFilePath) {
                directFiles.append(fileURL)
                knownDirectFilePaths.insert(normalizedFilePath)
            }

            if !knownImagePaths.contains(normalizedFilePath) {
                images.append(ExportableImage(url: fileURL))
                knownImagePaths.insert(normalizedFilePath)
            }
        }

        return BuildExportImageListResult(
            images: images,
            folders: folders,
            directFiles: directFiles,
            importedRootFolders: rootFolders
        )
    }

    nonisolated private func scanSupportedFiles(in folder: URL) -> [URL] {
        accessCoordinator.withAccess(to: folder) {
            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            var files: [URL] = []
            while let fileURL = enumerator.nextObject() as? URL {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                   !isDirectory.boolValue,
                   isSupportedFile(fileURL) {
                    files.append(fileURL)
                }
            }
            return files
        }
    }

    nonisolated private func isSupportedFile(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    nonisolated private func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.path
    }
}
