import XCTest
@testable import RetoFlow

@MainActor
final class FileRenamerUseCaseTests: XCTestCase {
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

    func testGenerateRenamePreviewAppliesRulesInOrder() {
        let files = [
            RenamableFile(
                originalURL: URL(fileURLWithPath: "/tmp/IMG_0001.JPG"),
                newFilename: "IMG_0001.JPG"
            )
        ]
        let rules = [
            RenameRule(type: .replace, findText: "IMG_", replaceText: "photo_"),
            RenameRule(type: .suffix, suffixText: "_edited"),
            RenameRule(type: .extensionChange, newExtension: "jpeg")
        ]

        let useCase = GenerateRenamePreviewUseCase()

        let result = useCase.execute(files: files, rules: rules)

        XCTAssertEqual(result.first?.newFilename, "photo_0001_edited.jpeg")
    }

    func testApplyRenameMovesFileAndReportsSuccess() async throws {
        let originalURL = temporaryDirectory.appendingPathComponent("sample.txt")
        FileManager.default.createFile(atPath: originalURL.path, contents: Data("test".utf8))

        let files = [
            RenamableFile(
                originalURL: originalURL,
                newFilename: "renamed.txt"
            )
        ]

        let useCase = ApplyRenameRulesUseCase()

        let result = await useCase.execute(files: files)

        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(result.failureCount, 0)
        XCTAssertEqual(result.updatedFiles.first?.originalURL.lastPathComponent, "renamed.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryDirectory.appendingPathComponent("renamed.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalURL.path))
    }

    func testApplyRenameSkipsCollisionByDefaultAndPreservesOriginalFile() async throws {
        let originalURL = temporaryDirectory.appendingPathComponent("sample.txt")
        let collisionURL = temporaryDirectory.appendingPathComponent("renamed.txt")
        FileManager.default.createFile(atPath: originalURL.path, contents: Data("source".utf8))
        FileManager.default.createFile(atPath: collisionURL.path, contents: Data("existing".utf8))

        let files = [
            RenamableFile(
                originalURL: originalURL,
                newFilename: "renamed.txt"
            )
        ]

        let useCase = ApplyRenameRulesUseCase()

        let result = await useCase.execute(files: files)

        XCTAssertEqual(result.successCount, 0)
        XCTAssertEqual(result.failureCount, 0)
        XCTAssertEqual(result.skippedCount, 1)
        XCTAssertEqual(result.updatedFiles.first?.error, "目标文件已存在: \(collisionURL.lastPathComponent)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: originalURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: collisionURL.path))
    }
}
