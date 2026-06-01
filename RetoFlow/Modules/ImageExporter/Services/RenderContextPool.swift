import Foundation
import CoreImage
import Metal

final class ManagedRenderContext: @unchecked Sendable {
    let ciContext: CIContext

    nonisolated init(ciContext: CIContext) {
        self.ciContext = ciContext
    }
}

protocol RenderContextProviding: Sendable {
    nonisolated func acquireContext() async -> ManagedRenderContext
    nonisolated func releaseContext(_ context: ManagedRenderContext) async
}

final class RenderContextPool: RenderContextProviding {
    typealias ContextFactory = @Sendable () -> ManagedRenderContext

    private let lock = NSLock()
    private let maximumContextCount: Int
    private let contextFactory: ContextFactory
    nonisolated(unsafe) private var availableContexts: [ManagedRenderContext] = []
    nonisolated(unsafe) private var totalCreated = 0
    nonisolated(unsafe) private var waiters: [CheckedContinuation<ManagedRenderContext, Never>] = []

    nonisolated init(
        maximumContextCount: Int = min(8, max(1, ProcessInfo.processInfo.activeProcessorCount)),
        contextFactory: @escaping ContextFactory = { RenderContextPool.makeManagedContext() }
    ) {
        self.maximumContextCount = max(1, maximumContextCount)
        self.contextFactory = contextFactory
    }

    nonisolated func acquireContext() async -> ManagedRenderContext {
        let immediateContext = lock.withLock { () -> ManagedRenderContext? in
            if let context = availableContexts.popLast() {
                return context
            }

            if totalCreated < maximumContextCount {
                totalCreated += 1
                return contextFactory()
            }

            return nil
        }

        if let immediateContext {
            return immediateContext
        }

        return await withCheckedContinuation { continuation in
            lock.withLock {
                waiters.append(continuation)
            }
        }
    }

    nonisolated func releaseContext(_ context: ManagedRenderContext) async {
        let waiter = lock.withLock { () -> CheckedContinuation<ManagedRenderContext, Never>? in
            if waiters.isEmpty {
                availableContexts.append(context)
                return nil
            }

            return waiters.removeFirst()
        }

        waiter?.resume(returning: context)
    }

    nonisolated private static func makeManagedContext() -> ManagedRenderContext {
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .cacheIntermediates: false,
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any,
            .name: "ImageExporterContext"
        ]

        if let metalDevice = MTLCreateSystemDefaultDevice() {
            return ManagedRenderContext(
                ciContext: CIContext(mtlDevice: metalDevice, options: options)
            )
        }

        return ManagedRenderContext(ciContext: CIContext(options: options))
    }
}
