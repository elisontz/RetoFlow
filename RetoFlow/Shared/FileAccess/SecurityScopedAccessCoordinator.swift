import Foundation

protocol SecurityScopedAccessing: Sendable {
    nonisolated func register(url: URL)
    nonisolated func register(urls: [URL])
    nonisolated func withAccess<T>(to url: URL, _ operation: () throws -> T) rethrows -> T
    nonisolated func withAccess<T>(to urls: [URL], _ operation: () throws -> T) rethrows -> T
}

// Module-level constant: free from @MainActor inference that applies to static class members.
nonisolated private let _sharedSecurityScopedAccessCoordinator = SecurityScopedAccessCoordinator()

/// Returns the shared SecurityScopedAccessCoordinator instance.
/// Using a free function avoids @MainActor inference that applies to static class members.
nonisolated func sharedSecurityScopedAccessCoordinator() -> SecurityScopedAccessCoordinator {
    _sharedSecurityScopedAccessCoordinator
}

/// Thread-safe wrapper for the registered root URLs.
/// Declared as a separate final class so the compiler can verify Sendable conformance
/// without requiring @unchecked on SecurityScopedAccessCoordinator itself.
private final class LockedRoots: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var roots: [URL] = []

    nonisolated func append(_ url: URL) {
        lock.withLock { roots.append(url) }
    }

    nonisolated func contains(where predicate: (URL) -> Bool) -> Bool {
        lock.withLock { roots.contains(where: predicate) }
    }

    nonisolated func snapshot() -> [URL] {
        lock.withLock { roots }
    }
}

final class SecurityScopedAccessCoordinator: Sendable, SecurityScopedAccessing {
    static var shared: SecurityScopedAccessCoordinator { _sharedSecurityScopedAccessCoordinator }

    private let startAccessing: @Sendable (URL) -> Bool
    private let stopAccessing: @Sendable (URL) -> Void
    private let registeredRoots = LockedRoots()

    nonisolated init(
        startAccessing: @escaping @Sendable (URL) -> Bool = { $0.startAccessingSecurityScopedResource() },
        stopAccessing: @escaping @Sendable (URL) -> Void = { $0.stopAccessingSecurityScopedResource() }
    ) {
        self.startAccessing = startAccessing
        self.stopAccessing = stopAccessing
    }

    nonisolated func register(url: URL) {
        let normalizedURL = url.standardizedFileURL
        guard !registeredRoots.contains(where: { $0.path == normalizedURL.path }) else { return }
        registeredRoots.append(normalizedURL)
    }

    nonisolated func register(urls: [URL]) {
        for url in urls {
            register(url: url)
        }
    }

    nonisolated func withAccess<T>(to url: URL, _ operation: () throws -> T) rethrows -> T {
        try withAccess(to: [url], operation)
    }

    nonisolated func withAccess<T>(to urls: [URL], _ operation: () throws -> T) rethrows -> T {
        let accessRoots = resolvedAccessRoots(for: urls)
        var startedRoots: [URL] = []

        for accessRoot in accessRoots {
            if startAccessing(accessRoot) {
                startedRoots.append(accessRoot)
            }
        }

        defer {
            for accessRoot in startedRoots.reversed() {
                stopAccessing(accessRoot)
            }
        }

        return try operation()
    }

    nonisolated private func resolvedAccessRoots(for urls: [URL]) -> [URL] {
        let roots = registeredRoots.snapshot()
        var resolvedRoots: [URL] = []

        for url in urls {
            let resolvedRoot = resolvedAccessRoot(for: url.standardizedFileURL, roots: roots)
            if !resolvedRoots.contains(where: { $0.path == resolvedRoot.path }) {
                resolvedRoots.append(resolvedRoot)
            }
        }

        return resolvedRoots
    }

    nonisolated private func resolvedAccessRoot(for url: URL, roots: [URL]) -> URL {
        let ancestorMatches = roots.filter { root in
            Self.isSameOrDescendant(url, relativeTo: root)
        }

        if let nearestAncestor = ancestorMatches.max(by: { $0.path.count < $1.path.count }) {
            return nearestAncestor
        }

        let siblingMatches = roots.filter { root in
            let rootParent = root.deletingLastPathComponent().standardizedFileURL
            let targetParent = url.deletingLastPathComponent().standardizedFileURL
            return rootParent.path == targetParent.path || rootParent.path == url.path
        }

        if let siblingRoot = siblingMatches.max(by: { $0.path.count < $1.path.count }) {
            return siblingRoot
        }

        return url
    }

    nonisolated private static func isSameOrDescendant(_ url: URL, relativeTo root: URL) -> Bool {
        let urlPath = url.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        let rootPathWithSlash = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        return urlPath == rootPath || urlPath.hasPrefix(rootPathWithSlash)
    }
}
