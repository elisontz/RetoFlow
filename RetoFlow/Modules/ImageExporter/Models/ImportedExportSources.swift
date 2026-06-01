import Foundation

struct ImportedExportSources: Sendable {
    let candidateFiles: [URL]
    let candidateFolders: [URL]
}

struct BuildExportImageListResult: Sendable {
    let images: [ExportableImage]
    let folders: [URL]
    let directFiles: [URL]
    let importedRootFolders: Set<URL>
}
