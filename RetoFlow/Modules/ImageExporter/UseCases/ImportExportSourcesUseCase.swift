import Foundation
import UniformTypeIdentifiers

struct ImportExportSourcesUseCase: Sendable {
    private let itemProviderResolver: ItemProviderFileURLResolver
    private let accessCoordinator: any SecurityScopedAccessing

    nonisolated init(
        itemProviderResolver: ItemProviderFileURLResolver = ItemProviderFileURLResolver(),
        accessCoordinator: any SecurityScopedAccessing = sharedSecurityScopedAccessCoordinator()
    ) {
        self.itemProviderResolver = itemProviderResolver
        self.accessCoordinator = accessCoordinator
    }

    nonisolated func execute(providers: [NSItemProvider]) async -> ImportedExportSources {
        var candidateFiles: [URL] = []
        var candidateFolders: [URL] = []
        let fileManager = FileManager.default

        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
                  let url = await itemProviderResolver.resolve(from: provider) else {
                continue
            }

            var isDirectory: ObjCBool = false
            let exists = accessCoordinator.withAccess(to: url) {
                fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
            }
            guard exists else {
                continue
            }

            if isDirectory.boolValue {
                candidateFolders.append(url)
            } else {
                candidateFiles.append(url)
            }
        }

        return ImportedExportSources(
            candidateFiles: candidateFiles,
            candidateFolders: candidateFolders
        )
    }
}
