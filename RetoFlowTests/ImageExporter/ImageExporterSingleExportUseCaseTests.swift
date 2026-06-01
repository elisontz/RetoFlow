import XCTest
import CoreImage
import CoreGraphics
@testable import RetoFlow

@MainActor
final class ImageExporterSingleExportUseCaseTests: XCTestCase {
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

    func testExportSingleImageFailsWhenSourceCannotBeLoaded() async throws {
        let sourceURL = temporaryDirectory.appendingPathComponent("missing.jpg")
        let configuration = makeConfiguration(outputDirectory: temporaryDirectory)

        let pathResolver = ImageExportPathResolver()
        let renderExecutor = StubImageRenderExecutor { _, _ in
            .failure("无法加载图片")
        }
        let useCase = ExportSingleImageUseCase(
            renderExecutor: renderExecutor,
            pathResolver: pathResolver
        )

        let result = await useCase.execute(
            sourceURL: sourceURL,
            configuration: configuration,
            importedRootFolders: []
        )

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error, "无法加载图片")
        XCTAssertNil(result.outputURL)
    }

    func testExportSingleImageUsesSubfolderPathWhenRootFolderMatches() async throws {
        let rootFolder = temporaryDirectory.appendingPathComponent("album", isDirectory: true)
        let sourceURL = rootFolder.appendingPathComponent("day1/photo.jpg")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: sourceURL.path, contents: Data("source".utf8))

        let configuration = makeConfiguration(
            outputDirectory: temporaryDirectory,
            createSubfolder: true,
            overwriteExisting: true,
            subfolderSuffix: "_小图"
        )

        let renderExecutor = StubImageRenderExecutor { _, _ in
            .success(
                PreparedImageExport(
                    data: Data("jpg".utf8),
                    originalSize: CGSize(width: 4000, height: 3000),
                    exportedSize: CGSize(width: 2000, height: 1500),
                    compressionQuality: 0.82
                )
            )
        }
        let pathResolver = ImageExportPathResolver()
        let useCase = ExportSingleImageUseCase(
            renderExecutor: renderExecutor,
            pathResolver: pathResolver
        )

        let result = await useCase.execute(
            sourceURL: sourceURL,
            configuration: configuration,
            importedRootFolders: [rootFolder]
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(
            result.outputURL,
            rootFolder.appendingPathComponent("album_小图/day1/photo.jpg")
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL!.path))
    }

    func testExportSingleImageFailsWhenTargetExistsAndOverwriteDisabled() async throws {
        let sourceURL = temporaryDirectory.appendingPathComponent("photo.jpg")
        FileManager.default.createFile(atPath: sourceURL.path, contents: Data("source".utf8))

        let outputDirectory = temporaryDirectory.appendingPathComponent("output", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let existingOutputURL = outputDirectory.appendingPathComponent("photo.jpg")
        FileManager.default.createFile(atPath: existingOutputURL.path, contents: Data("existing".utf8))

        let configuration = makeConfiguration(
            outputDirectory: outputDirectory,
            createSubfolder: false,
            overwriteExisting: false
        )

        let renderExecutor = StubImageRenderExecutor { _, _ in
            .success(
                PreparedImageExport(
                    data: Data("jpg".utf8),
                    originalSize: CGSize(width: 4000, height: 3000),
                    exportedSize: CGSize(width: 2000, height: 1500),
                    compressionQuality: 0.82
                )
            )
        }
        let pathResolver = ImageExportPathResolver()
        let useCase = ExportSingleImageUseCase(
            renderExecutor: renderExecutor,
            pathResolver: pathResolver
        )

        let result = await useCase.execute(
            sourceURL: sourceURL,
            configuration: configuration,
            importedRootFolders: []
        )

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error, "文件已存在")
        XCTAssertNil(result.outputURL)
    }

    func testExportSingleImageDelegatesRenderingThroughExecutor() async throws {
        let sourceURL = temporaryDirectory.appendingPathComponent("photo.jpg")
        FileManager.default.createFile(atPath: sourceURL.path, contents: Data("source".utf8))

        let outputDirectory = temporaryDirectory.appendingPathComponent("output", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let configuration = makeConfiguration(outputDirectory: outputDirectory)

        let recorder = RenderRequestRecorder()
        let renderExecutor = StubImageRenderExecutor { request, _ in
            await recorder.record(request)
            return .success(
                PreparedImageExport(
                    data: Data("rendered".utf8),
                    originalSize: CGSize(width: 4032, height: 3024),
                    exportedSize: CGSize(width: 2016, height: 1512),
                    compressionQuality: 0.73
                )
            )
        }
        let useCase = ExportSingleImageUseCase(
            renderExecutor: renderExecutor,
            pathResolver: ImageExportPathResolver()
        )

        let result = await useCase.execute(
            sourceURL: sourceURL,
            configuration: configuration,
            importedRootFolders: []
        )

        let recordedRequest = await recorder.value
        let recordedSourceURL = recordedRequest?.sourceURL
        let recordedOutputDirectory = recordedRequest?.configuration.outputDirectory
        let recordedOverwriteExisting = recordedRequest?.configuration.overwriteExisting
        let expectedOutputURL = outputDirectory.appendingPathComponent("photo.jpg")

        XCTAssertEqual(recordedSourceURL, sourceURL)
        XCTAssertEqual(recordedOutputDirectory, outputDirectory)
        XCTAssertEqual(recordedOverwriteExisting, true)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.outputURL, expectedOutputURL)
        XCTAssertEqual(try Data(contentsOf: result.outputURL!), Data("rendered".utf8))
    }

    func testExportSingleImageUsesScopedAccessWhenWritingOutput() async throws {
        let sourceURL = temporaryDirectory.appendingPathComponent("photo.jpg")
        FileManager.default.createFile(atPath: sourceURL.path, contents: Data("source".utf8))

        let outputDirectory = temporaryDirectory.appendingPathComponent("output", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let configuration = makeConfiguration(outputDirectory: outputDirectory)
        let accessSpy = TestSecurityScopedAccessSpy()

        let renderExecutor = StubImageRenderExecutor { _, _ in
            .success(
                PreparedImageExport(
                    data: Data("rendered".utf8),
                    originalSize: CGSize(width: 4032, height: 3024),
                    exportedSize: CGSize(width: 2016, height: 1512),
                    compressionQuality: 0.73
                )
            )
        }
        let useCase = ExportSingleImageUseCase(
            renderExecutor: renderExecutor,
            pathResolver: ImageExportPathResolver(),
            accessCoordinator: accessSpy
        )

        let result = await useCase.execute(
            sourceURL: sourceURL,
            configuration: configuration,
            importedRootFolders: []
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(
            accessSpy.accessedURLBatches.last,
            [[sourceURL, outputDirectory.appendingPathComponent("photo.jpg")].map(\.standardizedFileURL)].first
        )
    }

    func testExportSingleImagePreservesRelativeFoldersWhenManualOutputDirectoryIsSelected() async throws {
        let rootFolder = temporaryDirectory.appendingPathComponent("album", isDirectory: true)
        let sourceURL = rootFolder.appendingPathComponent("day1/setA/photo.jpg")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: sourceURL.path, contents: Data("source".utf8))

        let outputDirectory = temporaryDirectory.appendingPathComponent("exports", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let configuration = makeConfiguration(
            outputDirectory: outputDirectory,
            createSubfolder: false,
            overwriteExisting: true
        )

        let renderExecutor = StubImageRenderExecutor { _, _ in
            .success(
                PreparedImageExport(
                    data: Data("rendered".utf8),
                    originalSize: CGSize(width: 4032, height: 3024),
                    exportedSize: CGSize(width: 2016, height: 1512),
                    compressionQuality: 0.73
                )
            )
        }
        let useCase = ExportSingleImageUseCase(
            renderExecutor: renderExecutor,
            pathResolver: ImageExportPathResolver()
        )

        let result = await useCase.execute(
            sourceURL: sourceURL,
            configuration: configuration,
            importedRootFolders: [rootFolder]
        )

        let expectedOutputURL = outputDirectory.appendingPathComponent("album_小图/day1/setA/photo.jpg")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.outputURL, expectedOutputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedOutputURL.path))
    }

    func testExportSingleImageWrapsManualOutputInRootSuffixFolderForImportedSubfolder() async throws {
        let dayFolder = temporaryDirectory.appendingPathComponent("day1", isDirectory: true)
        let importedFolder = dayFolder.appendingPathComponent("setA", isDirectory: true)
        let sourceURL = importedFolder.appendingPathComponent("photo.jpg")
        try FileManager.default.createDirectory(at: importedFolder, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: sourceURL.path, contents: Data("source".utf8))

        let outputDirectory = temporaryDirectory.appendingPathComponent("1111", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let configuration = makeConfiguration(
            outputDirectory: outputDirectory,
            createSubfolder: false,
            overwriteExisting: true
        )

        let renderExecutor = StubImageRenderExecutor { _, _ in
            .success(
                PreparedImageExport(
                    data: Data("rendered".utf8),
                    originalSize: CGSize(width: 4032, height: 3024),
                    exportedSize: CGSize(width: 2016, height: 1512),
                    compressionQuality: 0.73
                )
            )
        }
        let useCase = ExportSingleImageUseCase(
            renderExecutor: renderExecutor,
            pathResolver: ImageExportPathResolver()
        )

        let result = await useCase.execute(
            sourceURL: sourceURL,
            configuration: configuration,
            importedRootFolders: [importedFolder]
        )

        let expectedOutputURL = outputDirectory.appendingPathComponent("setA_小图/photo.jpg")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.outputURL, expectedOutputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedOutputURL.path))
    }

    func testImageProcessingPipelineKeepsOriginalSizeWhenNoResizeLimitsExist() throws {
        let sourceURL = temporaryDirectory.appendingPathComponent("photo.jpg")
        let image = makeImage(size: CGSize(width: 3200, height: 2400))
        let metadataRecorder = MetadataCallRecorder()

        let pipeline = ImageProcessingPipeline(
            loadImageImpl: { _ in image },
            extractMetadataImpl: { url in
                metadataRecorder.record(url)
                return ["ignored": true]
            },
            compressImageImpl: { _, quality, metadata, _, _ in
                XCTAssertEqual(quality, 0.9, accuracy: 0.0001)
                XCTAssertNil(metadata)
                return Data("compressed".utf8)
            }
        )
        var configuration = makeConfiguration(outputDirectory: temporaryDirectory)
        configuration.preserveMetadata = false

        let export = pipeline.prepareExport(
            sourceURL: sourceURL,
            configuration: configuration,
            ciContext: CIContext()
        )

        XCTAssertEqual(export?.originalSize, CGSize(width: 3200, height: 2400))
        XCTAssertEqual(export?.exportedSize, CGSize(width: 3200, height: 2400))
        XCTAssertEqual(export?.compressionQuality ?? 0, 0.9, accuracy: 0.0001)
        XCTAssertEqual(export?.data, Data("compressed".utf8))
        XCTAssertTrue(metadataRecorder.values.isEmpty)
    }

    func testImageRenderExecutorUsesScopedAccessWhenLoadingSourceImage() async throws {
        let sourceURL = temporaryDirectory.appendingPathComponent("photo.jpg")
        let accessSpy = TestSecurityScopedAccessSpy()
        let pipeline = ImageProcessingPipeline(
            loadImageImpl: { _ in CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 10, height: 10)) },
            extractMetadataImpl: { _ in nil },
            compressImageImpl: { _, _, _, _, _ in Data("jpeg".utf8) }
        )
        let executor = ImageRenderExecutor(
            pipeline: pipeline,
            contextProvider: RenderContextProviderStub(),
            executionQueue: DispatchQueue(label: "ImageRenderExecutorTests"),
            accessCoordinator: accessSpy
        )

        let result = await executor.execute(
            ImageRenderRequest(sourceURL: sourceURL, configuration: makeConfiguration(outputDirectory: temporaryDirectory)),
            contextProvider: nil
        )

        guard case .success = result else {
            XCTFail("Expected render success")
            return
        }
        XCTAssertEqual(accessSpy.accessedURLBatches, [[sourceURL.standardizedFileURL]])
    }

    func testImageProcessingPipelinePassesMetadataWhenPreserveMetadataEnabled() throws {
        let sourceURL = temporaryDirectory.appendingPathComponent("photo.jpg")
        let image = makeImage(size: CGSize(width: 2400, height: 1600))
        let metadata = ["Camera": "R5"]
        let compressionRecorder = CompressionRequestRecorder()

        let pipeline = ImageProcessingPipeline(
            loadImageImpl: { _ in image },
            extractMetadataImpl: { _ in metadata },
            compressImageImpl: { _, quality, metadata, _, _ in
                compressionRecorder.record(quality: quality, metadata: metadata)
                return Data("compressed".utf8)
            }
        )
        var configuration = makeConfiguration(outputDirectory: temporaryDirectory)
        configuration.preserveMetadata = true

        let export = pipeline.prepareExport(
            sourceURL: sourceURL,
            configuration: configuration,
            ciContext: CIContext()
        )

        let request = compressionRecorder.lastRequest
        XCTAssertEqual(request?.quality ?? 0, 0.9, accuracy: 0.0001)
        XCTAssertEqual(request?.metadata as? [String: String], metadata)
        XCTAssertEqual(export?.data, Data("compressed".utf8))
    }

    func testImageProcessingPipelineUsesQualityOptimizationWhenMaxFileSizeIsSet() throws {
        let sourceURL = temporaryDirectory.appendingPathComponent("photo.jpg")
        let image = makeImage(size: CGSize(width: 2000, height: 1500))
        let compressionRecorder = CompressionRequestRecorder()

        let pipeline = ImageProcessingPipeline(
            loadImageImpl: { _ in image },
            extractMetadataImpl: { _ in nil },
            compressImageImpl: { _, quality, _, _, _ in
                compressionRecorder.record(quality: quality, metadata: nil)
                let size = quality <= 0.78 ? 900 : 1_500
                return Data(count: size)
            }
        )
        var configuration = makeConfiguration(outputDirectory: temporaryDirectory)
        configuration.maxFileSizeBytes = 1_000

        let export = pipeline.prepareExport(
            sourceURL: sourceURL,
            configuration: configuration,
            ciContext: CIContext()
        )

        let qualities = compressionRecorder.qualities
        XCTAssertGreaterThan(qualities.count, 1)
        XCTAssertNotNil(export)
        XCTAssertEqual(export?.data.count, 900)
        XCTAssertLessThanOrEqual(export?.compressionQuality ?? 1, 0.78)
    }

    private func makeConfiguration(
        outputDirectory: URL,
        createSubfolder: Bool = false,
        overwriteExisting: Bool = true,
        subfolderSuffix: String = "_小图"
    ) -> ExportConfiguration {
        ExportConfiguration(
            maxWidth: nil,
            maxHeight: nil,
            maxLongEdge: nil,
            maxShortEdge: nil,
            maxFileSizeBytes: nil,
            outputDirectory: outputDirectory,
            overwriteExisting: overwriteExisting,
            preserveMetadata: true,
            createSubfolder: createSubfolder,
            subfolderSuffix: subfolderSuffix
        )
    }

    private func makeImage(size: CGSize) -> CIImage {
        CIImage(color: CIColor(red: 0.2, green: 0.4, blue: 0.8))
            .cropped(to: CGRect(origin: .zero, size: size))
    }
}

private struct RenderContextProviderStub: RenderContextProviding {
    nonisolated func acquireContext() async -> ManagedRenderContext {
        ManagedRenderContext(ciContext: CIContext(options: [.useSoftwareRenderer: true]))
    }

    nonisolated func releaseContext(_ context: ManagedRenderContext) async {}
}

private actor RenderRequestRecorder {
    private(set) var value: ImageRenderRequest?

    func record(_ request: ImageRenderRequest) {
        value = request
    }
}

private final class MetadataCallRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValues: [URL] = []

    var values: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storedValues
    }

    nonisolated func record(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }
        storedValues.append(url)
    }
}

private final class CompressionRequestRecorder: @unchecked Sendable {
    struct Request {
        let quality: Double
        let metadata: [String: Any]?
    }

    private let lock = NSLock()
    private var storedLastRequest: Request?
    private var storedQualities: [Double] = []

    var lastRequest: Request? {
        lock.lock()
        defer { lock.unlock() }
        return storedLastRequest
    }

    var qualities: [Double] {
        lock.lock()
        defer { lock.unlock() }
        return storedQualities
    }

    nonisolated func record(quality: Double, metadata: [String: Any]?) {
        lock.lock()
        defer { lock.unlock() }
        storedLastRequest = Request(quality: quality, metadata: metadata)
        storedQualities.append(quality)
    }
}

private struct StubImageRenderExecutor: ImageRenderExecuting {
    private let executeImpl: @Sendable (ImageRenderRequest, RenderContextProviding?) async -> ImageRenderResult

    init(
        executeImpl: @escaping @Sendable (ImageRenderRequest, RenderContextProviding?) async -> ImageRenderResult
    ) {
        self.executeImpl = executeImpl
    }

    nonisolated func execute(
        _ request: ImageRenderRequest,
        contextProvider: RenderContextProviding?
    ) async -> ImageRenderResult {
        await executeImpl(request, contextProvider)
    }
}
