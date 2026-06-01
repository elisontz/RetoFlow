import XCTest
@testable import RetoFlow

@MainActor
final class EditedImageOrganizerUseCaseTests: XCTestCase {
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

    func testScanAndCompareReturnsScannedFilesDiffsAndCounts() async throws {
        let checkedRoot = temporaryDirectory.appendingPathComponent("checked", isDirectory: true)
        let originalRoot = temporaryDirectory.appendingPathComponent("original", isDirectory: true)

        try FileManager.default.createDirectory(at: checkedRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: originalRoot, withIntermediateDirectories: true)

        try makeFile(at: checkedRoot.appendingPathComponent("matched.jpg"))
        try makeFile(at: checkedRoot.appendingPathComponent("extra.jpg"))
        try makeFile(at: originalRoot.appendingPathComponent("matched.jpg"))
        try makeFile(at: originalRoot.appendingPathComponent("missing.jpg"))

        let useCase = ScanAndCompareImagesUseCase()

        let result = try await useCase.execute(
            checkedFolderURL: checkedRoot,
            originalFolderURL: originalRoot
        )

        XCTAssertEqual(result.checkedFiles.map(\.filename).sorted(), ["extra.jpg", "matched.jpg"])
        XCTAssertEqual(result.originalFiles.map(\.filename).sorted(), ["matched.jpg", "missing.jpg"])
        XCTAssertEqual(result.statusCounts[.mismatch], 2)
        XCTAssertEqual(result.statusCounts[.match], 1)
        XCTAssertEqual(result.diffResults.map(\.displayName), ["extra.jpg", "missing.jpg", "matched.jpg"])
    }

    func testScanAndCompareWithOneFolderReturnsFilesWithoutDiffs() async throws {
        let checkedRoot = temporaryDirectory.appendingPathComponent("checked", isDirectory: true)
        try FileManager.default.createDirectory(at: checkedRoot, withIntermediateDirectories: true)
        try makeFile(at: checkedRoot.appendingPathComponent("only.jpg"))

        let useCase = ScanAndCompareImagesUseCase()

        let result = try await useCase.execute(
            checkedFolderURL: checkedRoot,
            originalFolderURL: nil
        )

        XCTAssertEqual(result.checkedFiles.map(\.filename), ["only.jpg"])
        XCTAssertTrue(result.originalFiles.isEmpty)
        XCTAssertTrue(result.diffResults.isEmpty)
        XCTAssertEqual(result.statusCounts[.match], 0)
        XCTAssertEqual(result.statusCounts[.mismatch], 0)
    }

    func testOrganizeMovesMatchedAndUnmatchedFilesToExpectedLocations() async throws {
        let checkedRoot = temporaryDirectory.appendingPathComponent("checked", isDirectory: true)
        let originalRoot = temporaryDirectory.appendingPathComponent("original", isDirectory: true)

        try FileManager.default.createDirectory(at: checkedRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: originalRoot, withIntermediateDirectories: true)

        let matchedChecked = checkedRoot.appendingPathComponent("matched.jpg")
        let unmatchedChecked = checkedRoot.appendingPathComponent("extra.jpg")
        let originalMatch = originalRoot
            .appendingPathComponent("session", isDirectory: true)
            .appendingPathComponent("matched.jpg")

        try FileManager.default.createDirectory(at: originalMatch.deletingLastPathComponent(), withIntermediateDirectories: true)
        try makeFile(at: matchedChecked)
        try makeFile(at: unmatchedChecked)
        try makeFile(at: originalMatch)

        let diffResults = [
            DiffResult(
                status: .match,
                checkedFile: ImageFile(filename: matchedChecked.lastPathComponent, url: matchedChecked),
                originalFile: ImageFile(filename: originalMatch.lastPathComponent, url: originalMatch)
            ),
            DiffResult(
                status: .mismatch,
                checkedFile: ImageFile(filename: unmatchedChecked.lastPathComponent, url: unmatchedChecked),
                originalFile: nil
            )
        ]

        let useCase = OrganizeEditedImagesUseCase()

        let result = await useCase.execute(
            diffResults: diffResults,
            checkedRoot: checkedRoot,
            originalRoot: originalRoot
        )

        XCTAssertEqual(result.movedCount, 2)
        XCTAssertEqual(result.skippedCount, 0)
        XCTAssertEqual(result.failedCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: checkedRoot.appendingPathComponent("session/matched.jpg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: checkedRoot.appendingPathComponent("未整理/extra.jpg").path))
    }

    func testOrganizeSkipsWhenDestinationAlreadyExists() async throws {
        let checkedRoot = temporaryDirectory.appendingPathComponent("checked", isDirectory: true)
        let originalRoot = temporaryDirectory.appendingPathComponent("original", isDirectory: true)
        try FileManager.default.createDirectory(at: checkedRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: originalRoot, withIntermediateDirectories: true)

        let checkedFileURL = checkedRoot.appendingPathComponent("matched.jpg")
        let originalFileURL = originalRoot.appendingPathComponent("session/matched.jpg")
        let destinationURL = checkedRoot.appendingPathComponent("session/matched.jpg")

        try makeFile(at: checkedFileURL)
        try makeFile(at: originalFileURL)
        try makeFile(at: destinationURL)

        let diffResults = [
            DiffResult(
                status: .match,
                checkedFile: ImageFile(filename: checkedFileURL.lastPathComponent, url: checkedFileURL),
                originalFile: ImageFile(filename: originalFileURL.lastPathComponent, url: originalFileURL)
            )
        ]

        let useCase = OrganizeEditedImagesUseCase()

        let result = await useCase.execute(
            diffResults: diffResults,
            checkedRoot: checkedRoot,
            originalRoot: originalRoot
        )

        XCTAssertEqual(result.movedCount, 0)
        XCTAssertEqual(result.skippedCount, 1)
        XCTAssertEqual(result.failedCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: checkedFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
    }

    func testOrganizeDoesNotMoveFilesAlreadyInExpectedLocation() async throws {
        let checkedRoot = temporaryDirectory.appendingPathComponent("checked", isDirectory: true)
        let originalRoot = temporaryDirectory.appendingPathComponent("original", isDirectory: true)
        try FileManager.default.createDirectory(at: checkedRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: originalRoot, withIntermediateDirectories: true)

        let checkedFileURL = checkedRoot.appendingPathComponent("session/matched.jpg")
        let originalFileURL = originalRoot.appendingPathComponent("session/matched.jpg")

        try makeFile(at: checkedFileURL)
        try makeFile(at: originalFileURL)

        let diffResults = [
            DiffResult(
                status: .match,
                checkedFile: ImageFile(filename: checkedFileURL.lastPathComponent, url: checkedFileURL),
                originalFile: ImageFile(filename: originalFileURL.lastPathComponent, url: originalFileURL)
            )
        ]

        let useCase = OrganizeEditedImagesUseCase()

        let result = await useCase.execute(
            diffResults: diffResults,
            checkedRoot: checkedRoot,
            originalRoot: originalRoot
        )

        XCTAssertEqual(result.movedCount, 0)
        XCTAssertEqual(result.skippedCount, 0)
        XCTAssertEqual(result.failedCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: checkedFileURL.path))
    }

    func testOrganizeContinuesAfterMoveFailureAndReportsFailureCount() async throws {
        let checkedRoot = temporaryDirectory.appendingPathComponent("checked", isDirectory: true)
        let originalRoot = temporaryDirectory.appendingPathComponent("original", isDirectory: true)
        try FileManager.default.createDirectory(at: checkedRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: originalRoot, withIntermediateDirectories: true)

        let failingCheckedURL = checkedRoot.appendingPathComponent("fail.jpg")
        let passingCheckedURL = checkedRoot.appendingPathComponent("pass.jpg")
        let failingOriginalURL = originalRoot.appendingPathComponent("setA/fail.jpg")
        let passingOriginalURL = originalRoot.appendingPathComponent("setB/pass.jpg")

        try makeFile(at: failingCheckedURL)
        try makeFile(at: passingCheckedURL)
        try makeFile(at: failingOriginalURL)
        try makeFile(at: passingOriginalURL)

        let diffResults = [
            DiffResult(
                status: .match,
                checkedFile: ImageFile(filename: failingCheckedURL.lastPathComponent, url: failingCheckedURL),
                originalFile: ImageFile(filename: failingOriginalURL.lastPathComponent, url: failingOriginalURL)
            ),
            DiffResult(
                status: .match,
                checkedFile: ImageFile(filename: passingCheckedURL.lastPathComponent, url: passingCheckedURL),
                originalFile: ImageFile(filename: passingOriginalURL.lastPathComponent, url: passingOriginalURL)
            )
        ]

        let fileOperations = EditedImageFileOperations(
            moveItemImpl: { source, destination in
                if source.lastPathComponent == "fail.jpg" {
                    throw EditedImageOrganizerError.moveFailed(source: source, destination: destination)
                }
                try FileManager.default.moveItem(at: source, to: destination)
            }
        )
        let useCase = OrganizeEditedImagesUseCase(fileOperations: fileOperations)

        let result = await useCase.execute(
            diffResults: diffResults,
            checkedRoot: checkedRoot,
            originalRoot: originalRoot
        )

        XCTAssertEqual(result.movedCount, 1)
        XCTAssertEqual(result.skippedCount, 0)
        XCTAssertEqual(result.failedCount, 1)
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: checkedRoot.appendingPathComponent("setB/pass.jpg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: failingCheckedURL.path))
    }

    func testScanAndCompareUsesScopedAccessWhenScanningSelectedFolders() async throws {
        let checkedRoot = temporaryDirectory.appendingPathComponent("checked", isDirectory: true)
        let originalRoot = temporaryDirectory.appendingPathComponent("original", isDirectory: true)
        try FileManager.default.createDirectory(at: checkedRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: originalRoot, withIntermediateDirectories: true)
        try makeFile(at: checkedRoot.appendingPathComponent("matched.jpg"))
        try makeFile(at: originalRoot.appendingPathComponent("matched.jpg"))

        let accessSpy = TestSecurityScopedAccessSpy()
        let useCase = ScanAndCompareImagesUseCase(
            scanner: EditedImageFileScanning(accessCoordinator: accessSpy)
        )

        _ = try await useCase.execute(
            checkedFolderURL: checkedRoot,
            originalFolderURL: originalRoot
        )

        XCTAssertEqual(
            accessSpy.accessedURLBatches,
            [
                [checkedRoot.standardizedFileURL],
                [checkedRoot.standardizedFileURL],
                [originalRoot.standardizedFileURL],
                [originalRoot.standardizedFileURL]
            ]
        )
    }

    private func makeFile(at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data("test".utf8)
        FileManager.default.createFile(atPath: url.path, contents: data)
    }
}
