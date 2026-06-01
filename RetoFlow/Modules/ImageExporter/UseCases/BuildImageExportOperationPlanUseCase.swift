import Foundation

struct BuildImageExportOperationPlanUseCase: Sendable {
    private let pathResolver: ImageExportPathResolver

    nonisolated init(pathResolver: ImageExportPathResolver = ImageExportPathResolver()) {
        self.pathResolver = pathResolver
    }

    nonisolated func execute(
        images: [ExportableImage],
        configuration: ExportConfiguration,
        importedRootFolders: Set<URL>
    ) -> OperationPlan {
        guard configuration.hasExplicitOutputTarget else {
            return OperationPlan(taskKind: "image-exporter", operations: [])
        }

        let operations = images.compactMap { image -> PlannedOperation? in
            guard let outputURL = try? pathResolver.resolveOutputURL(
                sourceURL: image.url,
                configuration: configuration,
                importedRootFolders: importedRootFolders
            ) else {
                return nil
            }

            return PlannedOperation(
                kind: .exportJPEG,
                sourceURL: image.url,
                destinationURL: outputURL,
                riskLevel: .medium,
                recoverability: .reproducible
            )
        }

        return OperationPlan(taskKind: "image-exporter", operations: operations)
    }
}
