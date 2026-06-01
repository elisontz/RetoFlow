import XCTest
@testable import RetoFlow

@MainActor
final class RawFinderUseCaseTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testScanAndMatchCollectsSupportedFilesAndMatchesByFilename() async throws {
        let imageRoot = temporaryDirectory.appendingPathComponent("images", isDirectory: true)
        let rawRoot = temporaryDirectory.appendingPathComponent("raws", isDirectory: true)
        try FileManager.default.createDirectory(at: imageRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rawRoot, withIntermediateDirectories: true)

        let directImage = temporaryDirectory.appendingPathComponent("picked.jpeg")

        try makeFile(at: imageRoot.appendingPathComponent("matched.jpg"))
        try makeFile(at: imageRoot.appendingPathComponent("extra.png"))
        try makeFile(at: rawRoot.appendingPathComponent("matched.ARW"))
        try makeFile(at: rawRoot.appendingPathComponent("unused.NEF"))
        try makeFile(at: directImage)

        let useCase = ScanAndMatchRawFilesUseCase()

        let result = await useCase.execute(
            imageFolders: [imageRoot],
            rawFolders: [rawRoot],
            directImageFiles: [directImage]
        )

        XCTAssertEqual(result.imageFiles.map(\.lastPathComponent).sorted(), ["extra.png", "matched.jpg", "picked.jpeg"])
        XCTAssertEqual(result.rawFiles.map(\.lastPathComponent).sorted(), ["matched.ARW", "unused.NEF"])
        XCTAssertEqual(result.matches.count, 3)
        XCTAssertEqual(result.statusCounts[.matched], 1)
        XCTAssertEqual(result.statusCounts[.missing], 2)
        XCTAssertEqual(result.matches.first(where: { $0.imageName == "matched.jpg" })?.rawName, "matched.ARW")
    }

    func testReplaceMatchedImagesRemovesImageAndCopiesRawBesideIt() async throws {
        let imageRoot = temporaryDirectory.appendingPathComponent("images", isDirectory: true)
        let rawRoot = temporaryDirectory.appendingPathComponent("raws", isDirectory: true)
        try FileManager.default.createDirectory(at: imageRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rawRoot, withIntermediateDirectories: true)

        let imageURL = imageRoot.appendingPathComponent("matched.jpg")
        let rawURL = rawRoot.appendingPathComponent("matched.arw")
        try makeFile(at: imageURL, contents: "image")
        try makeFile(at: rawURL, contents: "raw")

        let matches = [RawMatchPair(imageURL: imageURL, rawURL: rawURL)]
        let useCase = ReplaceImagesWithRawUseCase()

        let result = await useCase.execute(matches: matches)

        let copiedRawURL = imageRoot.appendingPathComponent("matched.arw")
        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(result.failureCount, 0)
        XCTAssertEqual(result.skippedCount, 0)
        XCTAssertEqual(result.removedImageURLs, [imageURL])
        XCTAssertFalse(FileManager.default.fileExists(atPath: imageURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: copiedRawURL.path))
    }

    func testReplaceMatchedImagesSkipsWhenTargetRawAlreadyExists() async throws {
        let imageRoot = temporaryDirectory.appendingPathComponent("images", isDirectory: true)
        let rawRoot = temporaryDirectory.appendingPathComponent("raws", isDirectory: true)
        try FileManager.default.createDirectory(at: imageRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rawRoot, withIntermediateDirectories: true)

        let imageURL = imageRoot.appendingPathComponent("matched.jpg")
        let rawURL = rawRoot.appendingPathComponent("matched.arw")
        let targetURL = imageRoot.appendingPathComponent("matched.arw")
        try makeFile(at: imageURL, contents: "image")
        try makeFile(at: rawURL, contents: "raw")
        try makeFile(at: targetURL, contents: "existing raw")

        let matches = [RawMatchPair(imageURL: imageURL, rawURL: rawURL)]
        let useCase = ReplaceImagesWithRawUseCase()

        let result = await useCase.execute(matches: matches)

        XCTAssertEqual(result.successCount, 0)
        XCTAssertEqual(result.failureCount, 0)
        XCTAssertEqual(result.skippedCount, 1)
        XCTAssertEqual(result.removedImageURLs, [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetURL.path))
    }

    func testReplaceMatchedImagesReportsExecutionFailures() async throws {
        let imageURL = temporaryDirectory.appendingPathComponent("images/matched.jpg")
        let rawURL = temporaryDirectory.appendingPathComponent("raws/matched.arw")
        try makeFile(at: imageURL, contents: "image")
        try makeFile(at: rawURL, contents: "raw")

        struct FailingCoordinator: FileAccessCoordinating {
            nonisolated func copyItem(at source: URL, to destination: URL) throws {
                throw FileAccessError.copyFailed(source: source, destination: destination)
            }

            nonisolated func moveItem(at source: URL, to destination: URL) throws {}
            nonisolated func renameItem(at source: URL, to destination: URL) throws {}
            nonisolated func trashItem(at source: URL) throws {}
            nonisolated func ensureDirectoryExists(at url: URL) throws {}
        }

        let useCase = ReplaceImagesWithRawUseCase(
            taskExecutionCenter: TaskExecutionCenter(fileAccessCoordinator: FailingCoordinator())
        )

        let result = await useCase.execute(matches: [RawMatchPair(imageURL: imageURL, rawURL: rawURL)])

        XCTAssertEqual(result.successCount, 0)
        XCTAssertEqual(result.failureCount, 1)
        XCTAssertEqual(result.skippedCount, 0)
        XCTAssertEqual(result.removedImageURLs, [imageURL])
    }

    func testScanAndMatchUsesScopedAccessWhenScanningInputFolders() async throws {
        let imageRoot = temporaryDirectory.appendingPathComponent("images", isDirectory: true)
        let rawRoot = temporaryDirectory.appendingPathComponent("raws", isDirectory: true)
        try FileManager.default.createDirectory(at: imageRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rawRoot, withIntermediateDirectories: true)

        try makeFile(at: imageRoot.appendingPathComponent("matched.jpg"))
        try makeFile(at: rawRoot.appendingPathComponent("matched.ARW"))

        let accessSpy = TestSecurityScopedAccessSpy()
        let useCase = ScanAndMatchRawFilesUseCase(
            scanner: RawFileScanning(accessCoordinator: accessSpy)
        )

        _ = await useCase.execute(
            imageFolders: [imageRoot],
            rawFolders: [rawRoot],
            directImageFiles: []
        )

        XCTAssertEqual(accessSpy.accessedURLBatches.count, 2)
        XCTAssertTrue(
            accessSpy.accessedURLBatches.contains([imageRoot.standardizedFileURL]),
            "Expected image root to be accessed"
        )
        XCTAssertTrue(
            accessSpy.accessedURLBatches.contains([rawRoot.standardizedFileURL]),
            "Expected raw root to be accessed"
        )
    }

    private func makeFile(at url: URL, contents: String = "test") throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: Data(contents.utf8))
    }
}
