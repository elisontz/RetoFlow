import XCTest
@testable import RetoFlow

final class ImageExporterOperationPlanTests: XCTestCase {
    func testBuildPlanRequiresExplicitOutputDirectoryWhenNotCreatingSubfolder() {
        let image = ExportableImage(url: URL(fileURLWithPath: "/tmp/source/photo.jpg"))
        let configuration = ExportConfiguration(
            maxWidth: nil,
            maxHeight: nil,
            maxLongEdge: nil,
            maxShortEdge: nil,
            maxFileSizeBytes: nil,
            outputDirectory: FileManager.default.temporaryDirectory,
            overwriteExisting: false,
            preserveMetadata: true,
            createSubfolder: false,
            subfolderSuffix: "_小图"
        )

        let useCase = BuildImageExportOperationPlanUseCase()

        let plan = useCase.execute(images: [image], configuration: configuration, importedRootFolders: [])

        XCTAssertTrue(plan.isEmpty)
    }

    func testBuildPlanDoesNotCreateDirectoriesWhileResolvingSubfolderOutput() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let rootFolder = temporaryDirectory.appendingPathComponent("album", isDirectory: true)
        let sourceFolder = rootFolder.appendingPathComponent("day1", isDirectory: true)
        let imageURL = sourceFolder.appendingPathComponent("photo.jpg")
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: imageURL.path, contents: Data("source".utf8))
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let configuration = ExportConfiguration(
            maxWidth: nil,
            maxHeight: nil,
            maxLongEdge: nil,
            maxShortEdge: nil,
            maxFileSizeBytes: nil,
            outputDirectory: FileManager.default.temporaryDirectory,
            overwriteExisting: false,
            preserveMetadata: true,
            createSubfolder: true,
            subfolderSuffix: "_小图"
        )

        let useCase = BuildImageExportOperationPlanUseCase()

        let plan = useCase.execute(
            images: [ExportableImage(url: imageURL)],
            configuration: configuration,
            importedRootFolders: [rootFolder]
        )

        let expectedDirectory = rootFolder
            .appendingPathComponent("album_小图")
            .appendingPathComponent("day1")

        XCTAssertEqual(plan.operations.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: expectedDirectory.path))
    }

    func testBuildPlanPreservesRelativeFoldersInsideManualOutputDirectory() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let rootFolder = temporaryDirectory.appendingPathComponent("album", isDirectory: true)
        let sourceFolder = rootFolder.appendingPathComponent("day1/setA", isDirectory: true)
        let imageURL = sourceFolder.appendingPathComponent("photo.jpg")
        let outputDirectory = temporaryDirectory.appendingPathComponent("exports", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: imageURL.path, contents: Data("source".utf8))
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let configuration = ExportConfiguration(
            maxWidth: nil,
            maxHeight: nil,
            maxLongEdge: nil,
            maxShortEdge: nil,
            maxFileSizeBytes: nil,
            outputDirectory: outputDirectory,
            overwriteExisting: false,
            preserveMetadata: true,
            createSubfolder: false,
            subfolderSuffix: "_小图"
        )

        let useCase = BuildImageExportOperationPlanUseCase()

        let plan = useCase.execute(
            images: [ExportableImage(url: imageURL)],
            configuration: configuration,
            importedRootFolders: [rootFolder]
        )

        XCTAssertEqual(plan.operations.count, 1)
        XCTAssertEqual(
            plan.operations.first?.destinationURL,
            outputDirectory.appendingPathComponent("album_小图/day1/setA/photo.jpg")
        )
    }

    func testBuildPlanWrapsManualOutputInRootSuffixFolderForImportedSubfolder() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let dayFolder = temporaryDirectory.appendingPathComponent("day1", isDirectory: true)
        let importedFolder = dayFolder.appendingPathComponent("setA", isDirectory: true)
        let imageURL = importedFolder.appendingPathComponent("photo.jpg")
        let outputDirectory = temporaryDirectory.appendingPathComponent("1111", isDirectory: true)
        try FileManager.default.createDirectory(at: importedFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: imageURL.path, contents: Data("source".utf8))
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let configuration = ExportConfiguration(
            maxWidth: nil,
            maxHeight: nil,
            maxLongEdge: nil,
            maxShortEdge: nil,
            maxFileSizeBytes: nil,
            outputDirectory: outputDirectory,
            overwriteExisting: false,
            preserveMetadata: true,
            createSubfolder: false,
            subfolderSuffix: "_小图"
        )

        let useCase = BuildImageExportOperationPlanUseCase()

        let plan = useCase.execute(
            images: [ExportableImage(url: imageURL)],
            configuration: configuration,
            importedRootFolders: [importedFolder]
        )

        XCTAssertEqual(plan.operations.count, 1)
        XCTAssertEqual(
            plan.operations.first?.destinationURL,
            outputDirectory.appendingPathComponent("setA_小图/photo.jpg")
        )
    }
}
