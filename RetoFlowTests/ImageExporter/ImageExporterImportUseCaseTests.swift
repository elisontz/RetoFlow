import XCTest
@testable import RetoFlow

@MainActor
final class ImageExporterImportUseCaseTests: XCTestCase {
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

    func testBuildExportImageListRecursivelyLoadsSupportedFilesOnly() throws {
        let folder = temporaryDirectory.appendingPathComponent("shoot", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let nestedJPEG = folder.appendingPathComponent("nested/photo.jpg")
        let nestedPSD = folder.appendingPathComponent("nested/raw-edit.psd")
        let ignoredTXT = folder.appendingPathComponent("nested/notes.txt")

        try makeFile(at: nestedJPEG)
        try makeFile(at: nestedPSD)
        try makeFile(at: ignoredTXT)

        let useCase = BuildExportImageListUseCase()

        let result = useCase.execute(
            sources: ImportedExportSources(candidateFiles: [], candidateFolders: [folder]),
            existingImages: [],
            existingFolders: [],
            existingDirectFiles: [],
            importedRootFolders: []
        )

        XCTAssertEqual(result.images.map(\.url.lastPathComponent).sorted(), ["photo.jpg", "raw-edit.psd"])
        XCTAssertEqual(result.folders, [folder])
        XCTAssertTrue(result.directFiles.isEmpty)
        XCTAssertEqual(result.importedRootFolders, [folder])
    }

    func testBuildExportImageListKeepsDirectFilesSeparateFromFolders() throws {
        let folder = temporaryDirectory.appendingPathComponent("album", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let folderImage = folder.appendingPathComponent("folder-image.png")
        let directImage = temporaryDirectory.appendingPathComponent("single.tif")
        let directUnsupported = temporaryDirectory.appendingPathComponent("single.heic")

        try makeFile(at: folderImage)
        try makeFile(at: directImage)
        try makeFile(at: directUnsupported)

        let useCase = BuildExportImageListUseCase()

        let result = useCase.execute(
            sources: ImportedExportSources(
                candidateFiles: [directImage, directUnsupported],
                candidateFolders: [folder]
            ),
            existingImages: [],
            existingFolders: [],
            existingDirectFiles: [],
            importedRootFolders: []
        )

        XCTAssertEqual(result.folders, [folder])
        XCTAssertEqual(result.directFiles, [directImage])
        XCTAssertEqual(
            Set(result.images.map(\.url.lastPathComponent)),
            ["folder-image.png", "single.tif"]
        )
    }

    func testBuildExportImageListDoesNotDuplicateExistingImagesAndFolders() throws {
        let folder = temporaryDirectory.appendingPathComponent("album", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let existingImageURL = folder.appendingPathComponent("existing.jpg")
        let directImageURL = temporaryDirectory.appendingPathComponent("single.png")

        try makeFile(at: existingImageURL)
        try makeFile(at: directImageURL)

        let useCase = BuildExportImageListUseCase()
        let existingImage = ExportableImage(url: existingImageURL)

        let result = useCase.execute(
            sources: ImportedExportSources(
                candidateFiles: [directImageURL],
                candidateFolders: [folder]
            ),
            existingImages: [existingImage],
            existingFolders: [folder],
            existingDirectFiles: [directImageURL],
            importedRootFolders: [folder]
        )

        XCTAssertEqual(result.images.count, 2)
        XCTAssertEqual(result.images.filter { $0.url == existingImageURL }.count, 1)
        XCTAssertEqual(result.images.filter { $0.url == directImageURL }.count, 1)
        XCTAssertEqual(result.folders, [folder])
        XCTAssertEqual(result.directFiles, [directImageURL])
        XCTAssertEqual(result.importedRootFolders, [folder])
    }

    func testImportExportSourcesSeparatesResolvedFilesAndFolders() async throws {
        let folder = temporaryDirectory.appendingPathComponent("album", isDirectory: true)
        let file = temporaryDirectory.appendingPathComponent("single.jpg")

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try makeFile(at: file)

        guard let fileProvider = NSItemProvider(contentsOf: file),
              let folderProvider = NSItemProvider(contentsOf: folder) else {
            XCTFail("Failed to create item providers")
            return
        }

        let useCase = ImportExportSourcesUseCase()

        let result = await useCase.execute(providers: [fileProvider, folderProvider])

        XCTAssertEqual(result.candidateFiles, [file])
        XCTAssertEqual(result.candidateFolders, [folder])
    }

    func testImportExportSourcesUsesScopedAccessWhenInspectingResolvedURLs() async throws {
        let folder = temporaryDirectory.appendingPathComponent("album", isDirectory: true)
        let file = temporaryDirectory.appendingPathComponent("single.jpg")

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try makeFile(at: file)

        guard let fileProvider = NSItemProvider(contentsOf: file),
              let folderProvider = NSItemProvider(contentsOf: folder) else {
            XCTFail("Failed to create item providers")
            return
        }

        let accessSpy = TestSecurityScopedAccessSpy()
        let useCase = ImportExportSourcesUseCase(accessCoordinator: accessSpy)

        _ = await useCase.execute(providers: [fileProvider, folderProvider])

        XCTAssertEqual(
            accessSpy.accessedURLBatches,
            [
                [file.standardizedFileURL],
                [folder.standardizedFileURL]
            ]
        )
    }

    func testBuildExportImageListUsesScopedAccessWhenScanningImportedFolders() throws {
        let folder = temporaryDirectory.appendingPathComponent("shoot", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let nestedJPEG = folder.appendingPathComponent("nested/photo.jpg")
        try makeFile(at: nestedJPEG)

        let accessSpy = TestSecurityScopedAccessSpy()
        let useCase = BuildExportImageListUseCase(accessCoordinator: accessSpy)

        let result = useCase.execute(
            sources: ImportedExportSources(candidateFiles: [], candidateFolders: [folder]),
            existingImages: [],
            existingFolders: [],
            existingDirectFiles: [],
            importedRootFolders: []
        )

        XCTAssertEqual(result.images.map(\.url.lastPathComponent), ["photo.jpg"])
        XCTAssertEqual(accessSpy.accessedURLBatches, [[folder.standardizedFileURL]])
    }

    private func makeFile(at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: Data("test".utf8))
    }
}
