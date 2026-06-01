import XCTest
@testable import RetoFlow

private final class PairRecorder: @unchecked Sendable {
    var movedPairs: [(URL, URL)] = []
    var copiedPairs: [(URL, URL)] = []
    var createdDirectories: [URL] = []
    var trashedURLs: [URL] = []
}

final class FileAccessCoordinatorTests: XCTestCase {
    func testMoveRefusesOverwriteWhenDestinationExists() throws {
        let sourceURL = URL(fileURLWithPath: "/tmp/source.txt")
        let destinationURL = URL(fileURLWithPath: "/tmp/existing.txt")
        let recorder = PairRecorder()
        let coordinator = FileAccessCoordinator(
            itemExists: { url in url.path == destinationURL.path },
            createDirectory: { _ in },
            copyItem: { _, _ in },
            moveItem: { source, destination in recorder.movedPairs.append((source, destination)) },
            trashItem: { _ in }
        )

        XCTAssertThrowsError(try coordinator.moveItem(at: sourceURL, to: destinationURL)) { error in
            XCTAssertEqual(error as? FileAccessError, .destinationAlreadyExists(destinationURL))
        }
        XCTAssertTrue(recorder.movedPairs.isEmpty)
    }

    func testRenameRefusesOverwriteWhenDestinationExists() throws {
        let sourceURL = URL(fileURLWithPath: "/tmp/source.txt")
        let destinationURL = URL(fileURLWithPath: "/tmp/existing.txt")
        let recorder = PairRecorder()
        let coordinator = FileAccessCoordinator(
            itemExists: { url in url.path == destinationURL.path },
            createDirectory: { _ in },
            copyItem: { _, _ in },
            moveItem: { source, destination in recorder.movedPairs.append((source, destination)) },
            trashItem: { _ in }
        )

        XCTAssertThrowsError(try coordinator.renameItem(at: sourceURL, to: destinationURL)) { error in
            XCTAssertEqual(error as? FileAccessError, .destinationAlreadyExists(destinationURL))
        }
        XCTAssertTrue(recorder.movedPairs.isEmpty)
    }

    func testCopyEnsuresParentDirectoryExistsBeforeCopying() throws {
        let sourceURL = URL(fileURLWithPath: "/tmp/source.txt")
        let destinationURL = URL(fileURLWithPath: "/tmp/output/copied.txt")
        let recorder = PairRecorder()
        let coordinator = FileAccessCoordinator(
            itemExists: { _ in false },
            createDirectory: { recorder.createdDirectories.append($0) },
            copyItem: { source, destination in recorder.copiedPairs.append((source, destination)) },
            moveItem: { _, _ in },
            trashItem: { _ in }
        )

        try coordinator.copyItem(at: sourceURL, to: destinationURL)

        XCTAssertEqual(recorder.createdDirectories, [destinationURL.deletingLastPathComponent()])
        XCTAssertEqual(recorder.copiedPairs.count, 1)
        XCTAssertEqual(recorder.copiedPairs.first?.0, sourceURL)
        XCTAssertEqual(recorder.copiedPairs.first?.1, destinationURL)
    }

    func testTrashDelegatesToTrashImplementation() throws {
        let sourceURL = URL(fileURLWithPath: "/tmp/source.txt")
        let recorder = PairRecorder()
        let coordinator = FileAccessCoordinator(
            itemExists: { _ in false },
            createDirectory: { _ in },
            copyItem: { _, _ in },
            moveItem: { _, _ in },
            trashItem: { recorder.trashedURLs.append($0) }
        )

        try coordinator.trashItem(at: sourceURL)

        XCTAssertEqual(recorder.trashedURLs, [sourceURL])
    }
}
