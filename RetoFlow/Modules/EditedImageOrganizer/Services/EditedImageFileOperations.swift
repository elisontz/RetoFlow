import Foundation

struct EditedImageFileOperations {
    private let ensureDirectoryExistsImpl: @Sendable (URL) throws -> Void
    private let itemExistsImpl: @Sendable (URL) -> Bool
    private let moveItemImpl: @Sendable (URL, URL) throws -> Void

    nonisolated init(
        ensureDirectoryExistsImpl: @escaping @Sendable (URL) throws -> Void = Self.defaultEnsureDirectoryExists,
        itemExistsImpl: @escaping @Sendable (URL) -> Bool = Self.defaultItemExists,
        moveItemImpl: @escaping @Sendable (URL, URL) throws -> Void = Self.defaultMoveItem
    ) {
        self.ensureDirectoryExistsImpl = ensureDirectoryExistsImpl
        self.itemExistsImpl = itemExistsImpl
        self.moveItemImpl = moveItemImpl
    }

    nonisolated func ensureDirectoryExists(at url: URL) throws {
        try ensureDirectoryExistsImpl(url)
    }

    nonisolated func itemExists(at url: URL) -> Bool {
        itemExistsImpl(url)
    }

    nonisolated func moveItem(at source: URL, to destination: URL) throws {
        try moveItemImpl(source, destination)
    }

    nonisolated private static func defaultEnsureDirectoryExists(at url: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            return
        }

        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw EditedImageOrganizerError.createDirectoryFailed(url)
        }
    }

    nonisolated private static func defaultItemExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    nonisolated private static func defaultMoveItem(from source: URL, to destination: URL) throws {
        do {
            try FileManager.default.moveItem(at: source, to: destination)
        } catch {
            throw EditedImageOrganizerError.moveFailed(source: source, destination: destination)
        }
    }
}
