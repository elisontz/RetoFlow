import Foundation
import UniformTypeIdentifiers

struct ItemProviderFileURLResolver: Sendable {
    private let accessCoordinator: any SecurityScopedAccessing

    nonisolated init(accessCoordinator: any SecurityScopedAccessing = sharedSecurityScopedAccessCoordinator()) {
        self.accessCoordinator = accessCoordinator
    }

    nonisolated func resolve(from provider: NSItemProvider) async -> URL? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
            return nil
        }

        if let url = await loadDataRepresentation(from: provider) {
            accessCoordinator.register(url: url)
            return url
        }

        guard let url = await loadFileRepresentation(from: provider) else {
            return nil
        }

        accessCoordinator.register(url: url)
        return url
    }

    nonisolated private func loadDataRepresentation(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: url)
            }
        }
    }

    nonisolated private func loadFileRepresentation(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }
}
