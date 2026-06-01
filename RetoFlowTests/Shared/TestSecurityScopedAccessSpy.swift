import Foundation
@testable import RetoFlow

final class TestSecurityScopedAccessSpy: @unchecked Sendable, SecurityScopedAccessing {
    private let lock = NSLock()
    private var _registeredURLs: [URL] = []
    private var _accessedURLBatches: [[URL]] = []

    var registeredURLs: [URL] {
        lock.withLock { _registeredURLs }
    }

    var accessedURLBatches: [[URL]] {
        lock.withLock { _accessedURLBatches }
    }

    func register(url: URL) {
        lock.withLock { _registeredURLs.append(url.standardizedFileURL) }
    }

    func register(urls: [URL]) {
        lock.withLock { _registeredURLs.append(contentsOf: urls.map(\.standardizedFileURL)) }
    }

    func withAccess<T>(to url: URL, _ operation: () throws -> T) rethrows -> T {
        lock.withLock { _accessedURLBatches.append([url.standardizedFileURL]) }
        return try operation()
    }

    func withAccess<T>(to urls: [URL], _ operation: () throws -> T) rethrows -> T {
        lock.withLock { _accessedURLBatches.append(urls.map(\.standardizedFileURL)) }
        return try operation()
    }
}
