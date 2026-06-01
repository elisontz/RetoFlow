import Foundation

protocol FileAccessCoordinating: Sendable {
    nonisolated func copyItem(at source: URL, to destination: URL) throws
    nonisolated func moveItem(at source: URL, to destination: URL) throws
    nonisolated func renameItem(at source: URL, to destination: URL) throws
    nonisolated func trashItem(at source: URL) throws
    nonisolated func ensureDirectoryExists(at url: URL) throws
}

struct FileAccessCoordinator: FileAccessCoordinating {
    nonisolated private let itemExists: @Sendable (URL) -> Bool
    nonisolated private let createDirectory: @Sendable (URL) throws -> Void
    nonisolated private let copyItemImpl: @Sendable (URL, URL) throws -> Void
    nonisolated private let moveItemImpl: @Sendable (URL, URL) throws -> Void
    nonisolated private let trashItemImpl: @Sendable (URL) throws -> Void

    nonisolated init(
        itemExists: @escaping @Sendable (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) },
        createDirectory: @escaping @Sendable (URL) throws -> Void = Self.defaultCreateDirectory,
        copyItem: @escaping @Sendable (URL, URL) throws -> Void = Self.defaultCopyItem,
        moveItem: @escaping @Sendable (URL, URL) throws -> Void = Self.defaultMoveItem,
        trashItem: @escaping @Sendable (URL) throws -> Void = Self.defaultTrashItem
    ) {
        self.itemExists = itemExists
        self.createDirectory = createDirectory
        self.copyItemImpl = copyItem
        self.moveItemImpl = moveItem
        self.trashItemImpl = trashItem
    }

    nonisolated func copyItem(at source: URL, to destination: URL) throws {
        try guardNoOverwrite(at: destination)
        try ensureDirectoryExists(at: destination.deletingLastPathComponent())

        do {
            try copyItemImpl(source, destination)
        } catch {
            throw FileAccessError.copyFailed(source: source, destination: destination)
        }
    }

    nonisolated func moveItem(at source: URL, to destination: URL) throws {
        try guardNoOverwrite(at: destination)
        try ensureDirectoryExists(at: destination.deletingLastPathComponent())

        do {
            try moveItemImpl(source, destination)
        } catch {
            throw FileAccessError.moveFailed(source: source, destination: destination)
        }
    }

    nonisolated func renameItem(at source: URL, to destination: URL) throws {
        try moveItem(at: source, to: destination)
    }

    nonisolated func trashItem(at source: URL) throws {
        do {
            try trashItemImpl(source)
        } catch {
            throw FileAccessError.trashFailed(source)
        }
    }

    nonisolated func ensureDirectoryExists(at url: URL) throws {
        guard !itemExists(url) else {
            return
        }

        do {
            try createDirectory(url)
        } catch {
            throw FileAccessError.createDirectoryFailed(url)
        }
    }

    nonisolated private func guardNoOverwrite(at destination: URL) throws {
        guard !itemExists(destination) else {
            throw FileAccessError.destinationAlreadyExists(destination)
        }
    }

    nonisolated private static func defaultCreateDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    nonisolated private static func defaultCopyItem(from source: URL, to destination: URL) throws {
        try FileManager.default.copyItem(at: source, to: destination)
    }

    nonisolated private static func defaultMoveItem(from source: URL, to destination: URL) throws {
        try FileManager.default.moveItem(at: source, to: destination)
    }

    nonisolated private static func defaultTrashItem(at source: URL) throws {
        var trashedItemURL: NSURL?
        try FileManager.default.trashItem(at: source, resultingItemURL: &trashedItemURL)
    }
}
