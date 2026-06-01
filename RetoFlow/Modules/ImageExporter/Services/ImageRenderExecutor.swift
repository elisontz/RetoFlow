import Foundation

struct ImageRenderRequest: Sendable {
    let sourceURL: URL
    let configuration: ExportConfiguration
}

enum ImageRenderResult: Sendable {
    case success(PreparedImageExport)
    case failure(String)
}

protocol ImageRenderExecuting: Sendable {
    nonisolated func execute(
        _ request: ImageRenderRequest,
        contextProvider: RenderContextProviding?
    ) async -> ImageRenderResult
}

struct ImageRenderExecutor: ImageRenderExecuting {
    private let pipeline: ImageProcessingPipeline
    private let defaultContextProvider: any RenderContextProviding
    private let executionQueue: DispatchQueue
    private let accessCoordinator: any SecurityScopedAccessing

    nonisolated init() {
        self.init(
            pipeline: ImageProcessingPipeline(),
            contextProvider: RenderContextPool(),
            executionQueue: DispatchQueue(
                label: "io.github.elisontz.RetoFlow.image-render-executor",
                qos: .userInitiated,
                attributes: .concurrent
            ),
            accessCoordinator: sharedSecurityScopedAccessCoordinator()
        )
    }

    nonisolated init(
        pipeline: ImageProcessingPipeline,
        contextProvider: any RenderContextProviding,
        executionQueue: DispatchQueue,
        accessCoordinator: any SecurityScopedAccessing = sharedSecurityScopedAccessCoordinator()
    ) {
        self.pipeline = pipeline
        self.defaultContextProvider = contextProvider
        self.executionQueue = executionQueue
        self.accessCoordinator = accessCoordinator
    }

    nonisolated func execute(
        _ request: ImageRenderRequest,
        contextProvider: RenderContextProviding?
    ) async -> ImageRenderResult {
        let provider = contextProvider ?? defaultContextProvider
        let managedContext = await provider.acquireContext()

        return await withCheckedContinuation { continuation in
            executionQueue.async {
                let result: ImageRenderResult
                if let preparedExport = accessCoordinator.withAccess(to: request.sourceURL, {
                    pipeline.prepareExport(
                        sourceURL: request.sourceURL,
                        configuration: request.configuration,
                        ciContext: managedContext.ciContext
                    )
                }) {
                    result = .success(preparedExport)
                } else {
                    result = .failure(String(localized: "无法加载图片"))
                }

                Task {
                    await provider.releaseContext(managedContext)
                    continuation.resume(returning: result)
                }
            }
        }
    }
}
