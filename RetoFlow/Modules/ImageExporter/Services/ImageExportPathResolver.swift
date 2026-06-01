import Foundation

enum ImageExportPathResolverError: LocalizedError {
    case createDirectoryFailed(String)

    var errorDescription: String? {
        switch self {
        case .createDirectoryFailed(let message):
            return message
        }
    }
}

struct ImageExportPathResolver {
    private let resolveOutputURLImpl: @Sendable (URL, ExportConfiguration, Set<URL>) throws -> URL

    nonisolated init(
        resolveOutputURLImpl: @escaping @Sendable (URL, ExportConfiguration, Set<URL>) throws -> URL = Self.defaultResolveOutputURL
    ) {
        self.resolveOutputURLImpl = resolveOutputURLImpl
    }

    nonisolated func resolveOutputURL(
        sourceURL: URL,
        configuration: ExportConfiguration,
        importedRootFolders: Set<URL>
    ) throws -> URL {
        try resolveOutputURLImpl(sourceURL, configuration, importedRootFolders)
    }

    nonisolated private static func defaultResolveOutputURL(
        sourceURL: URL,
        configuration: ExportConfiguration,
        importedRootFolders: Set<URL>
    ) throws -> URL {
        let outputFileName = sourceURL.deletingPathExtension().lastPathComponent + ".jpg"
        let sourceFolder = sourceURL.deletingLastPathComponent()

        if configuration.createSubfolder {
            if let rootFolder = findRootFolder(for: sourceURL, importedRootFolders: importedRootFolders) {
                let rootFolderName = rootFolder.lastPathComponent
                let subfolderURL = rootFolder.appendingPathComponent(rootFolderName + configuration.subfolderSuffix)
                let outputDirectory = appendRelativePath(
                    from: sourceFolder,
                    rootFolder: rootFolder,
                    to: subfolderURL
                )

                return outputDirectory.appendingPathComponent(outputFileName)
            }

            let sourceFolderName = sourceFolder.lastPathComponent
            let subfolderURL = sourceFolder.appendingPathComponent(sourceFolderName + configuration.subfolderSuffix)
            return subfolderURL.appendingPathComponent(outputFileName)
        }

        if let rootFolder = findRootFolder(for: sourceURL, importedRootFolders: importedRootFolders) {
            let outputBaseDirectory = manualOutputBaseDirectory(
                outputDirectory: configuration.outputDirectory,
                rootFolder: rootFolder,
                subfolderSuffix: configuration.subfolderSuffix
            )
            let outputDirectory = appendRelativePath(
                from: sourceFolder,
                rootFolder: rootFolder,
                to: outputBaseDirectory
            )
            return outputDirectory.appendingPathComponent(outputFileName)
        }

        return configuration.outputDirectory.appendingPathComponent(outputFileName)
    }

    nonisolated private static func appendRelativePath(
        from sourceFolder: URL,
        rootFolder: URL,
        to baseDirectory: URL
    ) -> URL {
        let sourceFolderPath = sourceFolder.standardizedFileURL.path
        let rootPath = rootFolder.standardizedFileURL.path
        let rootPathWithSlash = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"

        if sourceFolderPath == rootPath {
            return baseDirectory
        }

        if sourceFolderPath.hasPrefix(rootPathWithSlash) {
            let relativePath = String(sourceFolderPath.dropFirst(rootPathWithSlash.count))
            return baseDirectory.appendingPathComponent(relativePath)
        }

        return baseDirectory
    }

    nonisolated private static func manualOutputBaseDirectory(
        outputDirectory: URL,
        rootFolder: URL,
        subfolderSuffix: String
    ) -> URL {
        outputDirectory.appendingPathComponent(rootFolder.lastPathComponent + subfolderSuffix)
    }

    nonisolated private static func findRootFolder(for fileURL: URL, importedRootFolders: Set<URL>) -> URL? {
        let filePath = fileURL.standardizedFileURL.path
        let sortedRoots = importedRootFolders.sorted { $0.path.count > $1.path.count }

        for rootFolder in sortedRoots {
            let rootPath = rootFolder.standardizedFileURL.path
            let rootPathWithSlash = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"

            if filePath == rootPath || filePath.hasPrefix(rootPathWithSlash) {
                return rootFolder
            }
        }

        return nil
    }
}
