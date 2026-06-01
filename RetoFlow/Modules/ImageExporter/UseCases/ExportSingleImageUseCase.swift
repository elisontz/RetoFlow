import Foundation
import CoreGraphics

struct ExportSingleImageUseCase: Sendable {
    private let renderExecutor: any ImageRenderExecuting
    private let pathResolver: ImageExportPathResolver
    private let accessCoordinator: any SecurityScopedAccessing

    nonisolated init(
        renderExecutor: any ImageRenderExecuting = ImageRenderExecutor(),
        pathResolver: ImageExportPathResolver = ImageExportPathResolver(),
        accessCoordinator: any SecurityScopedAccessing = sharedSecurityScopedAccessCoordinator()
    ) {
        self.renderExecutor = renderExecutor
        self.pathResolver = pathResolver
        self.accessCoordinator = accessCoordinator
    }

    nonisolated func execute(
        sourceURL: URL,
        configuration: ExportConfiguration,
        importedRootFolders: Set<URL>
    ) async -> ExportResult {
        if Task.isCancelled {
            return ExportResult.failure(
                sourceURL: sourceURL,
                originalSize: .zero,
                error: String(localized: "已取消")
            )
        }

        let renderResult = await renderExecutor.execute(
            ImageRenderRequest(sourceURL: sourceURL, configuration: configuration),
            contextProvider: nil
        )

        let preparedExport: PreparedImageExport
        switch renderResult {
        case .success(let value):
            preparedExport = value
        case .failure(let error):
            return ExportResult.failure(
                sourceURL: sourceURL,
                originalSize: .zero,
                error: error
            )
        }

        if Task.isCancelled {
            return ExportResult.failure(
                sourceURL: sourceURL,
                originalSize: preparedExport.originalSize,
                error: String(localized: "已取消")
            )
        }

        let outputURL: URL
        do {
            outputURL = try pathResolver.resolveOutputURL(
                sourceURL: sourceURL,
                configuration: configuration,
                importedRootFolders: importedRootFolders
            )
        } catch {
            return ExportResult.failure(
                sourceURL: sourceURL,
                originalSize: preparedExport.originalSize,
                error: error.localizedDescription
            )
        }

        if Task.isCancelled {
            return ExportResult.failure(
                sourceURL: sourceURL,
                originalSize: preparedExport.originalSize,
                error: String(localized: "已取消")
            )
        }

        do {
            let fileAlreadyExists = accessCoordinator.withAccess(to: [sourceURL, outputURL]) {
                FileManager.default.fileExists(atPath: outputURL.path)
            }
            if fileAlreadyExists && !configuration.overwriteExisting {
                return ExportResult.failure(
                    sourceURL: sourceURL,
                    originalSize: preparedExport.originalSize,
                    error: String(localized: "文件已存在")
                )
            }

            try accessCoordinator.withAccess(to: [sourceURL, outputURL]) {
                try FileManager.default.createDirectory(
                    at: outputURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try preparedExport.data.write(to: outputURL)
            }
        } catch {
            return ExportResult.failure(
                sourceURL: sourceURL,
                originalSize: preparedExport.originalSize,
                error: String(localized: "保存文件失败: \(error.localizedDescription)")
            )
        }

        return ExportResult.success(
            sourceURL: sourceURL,
            outputURL: outputURL,
            originalSize: preparedExport.originalSize,
            exportedSize: preparedExport.exportedSize,
            fileSizeBytes: preparedExport.data.count,
            compressionQuality: preparedExport.compressionQuality
        )
    }
}
