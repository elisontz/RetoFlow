import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import RetoFlow

@MainActor
final class ImageExporterBatchExportUseCaseTests: XCTestCase {
    func testExecuteEmitsProgressUntilCompletion() async throws {
        let images = [
            ExportableImage(url: URL(fileURLWithPath: "/tmp/a.jpg")),
            ExportableImage(url: URL(fileURLWithPath: "/tmp/b.jpg"))
        ]
        let configuration = makeConfiguration()
        let sourceURLs = images.map { $0.url }
        let outputDirectory = configuration.outputDirectory
        let recorder = BatchEventRecorder()
        let useCase = ExportImagesUseCase(
            exportImage: { sourceURL, _, _ in
                ExportResult.success(
                    sourceURL: sourceURL,
                    outputURL: sourceURL.deletingPathExtension().appendingPathExtension("jpg"),
                    originalSize: CGSize(width: 4000, height: 3000),
                    exportedSize: CGSize(width: 2000, height: 1500),
                    fileSizeBytes: 1_024,
                    compressionQuality: 0.82
                )
            },
            concurrencyDecision: { _, _ in
                ExportBatchDecision(concurrency: 2, reason: "test")
            },
            preflightService: makePassingPreflightService(for: sourceURLs, outputDirectory: outputDirectory)
        )

        let summary = await useCase.execute(
            images: images,
            configuration: configuration,
            importedRootFolders: []
        ) { event in
            await recorder.record(event)
        }

        let events = await recorder.events
        let progressPairs = events.compactMap { event -> (Int, Int)? in
            guard case let .progress(completedCount, totalCount) = event else { return nil }
            return (completedCount, totalCount)
        }
        let finishedSummary = events.compactMap { event -> ExportBatchSummary? in
            guard case let .finished(summary) = event else { return nil }
            return summary
        }.last

        XCTAssertEqual(progressPairs.count, 3)
        guard progressPairs.count == 3 else {
            XCTFail("Expected 3 progress events, got \(progressPairs.count)")
            return
        }
        XCTAssertEqual(progressPairs[0].0, 0)
        XCTAssertEqual(progressPairs[0].1, 2)
        XCTAssertEqual(progressPairs[1].0, 1)
        XCTAssertEqual(progressPairs[1].1, 2)
        XCTAssertEqual(progressPairs[2].0, 2)
        XCTAssertEqual(progressPairs[2].1, 2)
        XCTAssertEqual(events.filter(\.isStarted).count, 2)
        XCTAssertEqual(events.filter(\.isCompleted).count, 2)
        XCTAssertEqual(summary.successCount, 2)
        XCTAssertEqual(summary.failureCount, 0)
        XCTAssertEqual(finishedSummary?.successCount, 2)
        XCTAssertEqual(finishedSummary?.failureCount, 0)
    }

    func testExecuteContinuesAfterFailureAndReportsSummary() async throws {
        let images = [
            ExportableImage(url: URL(fileURLWithPath: "/tmp/a.jpg")),
            ExportableImage(url: URL(fileURLWithPath: "/tmp/b.jpg")),
            ExportableImage(url: URL(fileURLWithPath: "/tmp/c.jpg"))
        ]
        let configuration = makeConfiguration()
        let sourceURLs = images.map { $0.url }
        let outputDirectory = configuration.outputDirectory
        let recorder = BatchEventRecorder()
        let useCase = ExportImagesUseCase(
            exportImage: { sourceURL, _, _ in
                if sourceURL.lastPathComponent == "b.jpg" {
                    return ExportResult.failure(
                        sourceURL: sourceURL,
                        originalSize: CGSize(width: 3000, height: 2000),
                        error: "boom"
                    )
                }

                return ExportResult.success(
                    sourceURL: sourceURL,
                    outputURL: sourceURL.deletingPathExtension().appendingPathExtension("jpg"),
                    originalSize: CGSize(width: 4000, height: 3000),
                    exportedSize: CGSize(width: 2000, height: 1500),
                    fileSizeBytes: 2_048,
                    compressionQuality: 0.76
                )
            },
            concurrencyDecision: { _, _ in
                ExportBatchDecision(concurrency: 2, reason: "test")
            },
            preflightService: makePassingPreflightService(for: sourceURLs, outputDirectory: outputDirectory)
        )

        let summary = await useCase.execute(
            images: images,
            configuration: configuration,
            importedRootFolders: []
        ) { event in
            await recorder.record(event)
        }

        let events = await recorder.events
        let completedResults = events.compactMap { event -> ExportResult? in
            guard case let .completed(_, result, _) = event else { return nil }
            return result
        }
        let finishedSummary = events.compactMap { event -> ExportBatchSummary? in
            guard case let .finished(summary) = event else { return nil }
            return summary
        }.last

        XCTAssertEqual(completedResults.count, 3)
        XCTAssertEqual(completedResults.filter(\.success).count, 2)
        XCTAssertEqual(completedResults.filter { !$0.success }.count, 1)
        XCTAssertEqual(summary.successCount, 2)
        XCTAssertEqual(summary.failureCount, 1)
        XCTAssertEqual(summary.skippedCount, 0)
        XCTAssertEqual(finishedSummary?.successCount, 2)
        XCTAssertEqual(finishedSummary?.failureCount, 1)
    }

    func testExecuteSkipsCollidingOutputsAndReportsOutputDirectorySummary() async throws {
        let imageURL = URL(fileURLWithPath: "/tmp/source/a.jpg")
        let images = [ExportableImage(url: imageURL)]
        let outputDirectory = URL(fileURLWithPath: "/tmp/output")
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
        let recorder = BatchEventRecorder()
        let useCase = ExportImagesUseCase(
            exportImage: { _, _, _ in
                XCTFail("Export should not run for skipped collisions")
                return ExportResult.failure(
                    sourceURL: imageURL,
                    originalSize: CGSize(width: 3000, height: 2000),
                    error: "unexpected"
                )
            },
            concurrencyDecision: { _, _ in
                ExportBatchDecision(concurrency: 1, reason: "test")
            },
            buildPlanUseCase: BuildImageExportOperationPlanUseCase(
                pathResolver: ImageExportPathResolver(
                    resolveOutputURLImpl: { _, _, _ in outputDirectory.appendingPathComponent("a.jpg") }
                )
            ),
            preflightService: OperationPreflightService(
                itemExists: { url in url.path == outputDirectory.appendingPathComponent("a.jpg").path },
                isWritable: { _ in true }
            )
        )

        let summary = await useCase.execute(
            images: images,
            configuration: configuration,
            importedRootFolders: []
        ) { event in
            await recorder.record(event)
        }

        XCTAssertEqual(summary.successCount, 0)
        XCTAssertEqual(summary.failureCount, 0)
        XCTAssertEqual(summary.skippedCount, 1)
        XCTAssertEqual(summary.outputDirectorySummary, outputDirectory.path)
    }

    func testExecuteAllowsOverwriteWhenConfiguredEvenIfDestinationExists() async throws {
        let imageURL = URL(fileURLWithPath: "/tmp/source/a.jpg")
        let images = [ExportableImage(url: imageURL)]
        let outputDirectory = URL(fileURLWithPath: "/tmp/output")
        let destinationURL = outputDirectory.appendingPathComponent("a.jpg")
        let configuration = ExportConfiguration(
            maxWidth: nil,
            maxHeight: nil,
            maxLongEdge: nil,
            maxShortEdge: nil,
            maxFileSizeBytes: nil,
            outputDirectory: outputDirectory,
            overwriteExisting: true,
            preserveMetadata: true,
            createSubfolder: false,
            subfolderSuffix: "_小图"
        )
        let recorder = BatchEventRecorder()
        let useCase = ExportImagesUseCase(
            exportImage: { sourceURL, _, _ in
                ExportResult.success(
                    sourceURL: sourceURL,
                    outputURL: destinationURL,
                    originalSize: CGSize(width: 4000, height: 3000),
                    exportedSize: CGSize(width: 2000, height: 1500),
                    fileSizeBytes: 1_024,
                    compressionQuality: 0.82
                )
            },
            concurrencyDecision: { _, _ in
                ExportBatchDecision(concurrency: 1, reason: "test")
            },
            buildPlanUseCase: BuildImageExportOperationPlanUseCase(
                pathResolver: ImageExportPathResolver(
                    resolveOutputURLImpl: { _, _, _ in destinationURL }
                )
            ),
            preflightService: OperationPreflightService(
                itemExists: { url in
                    url.path == imageURL.path || url.path == destinationURL.path || url.path == outputDirectory.path || url.path == "/tmp"
                },
                isWritable: { _ in true }
            )
        )

        let summary = await useCase.execute(
            images: images,
            configuration: configuration,
            importedRootFolders: []
        ) { event in
            await recorder.record(event)
        }

        let completedResults = await recorder.events.compactMap { event -> ExportResult? in
            guard case let .completed(_, result, _) = event else { return nil }
            return result
        }

        XCTAssertEqual(summary.successCount, 1)
        XCTAssertEqual(summary.failureCount, 0)
        XCTAssertEqual(summary.skippedCount, 0)
        XCTAssertEqual(completedResults.count, 1)
        XCTAssertEqual(completedResults.first?.outputURL, destinationURL)
    }

    func testExecuteStopsSchedulingAfterCancellationAndMarksSummaryCancelled() async throws {
        let images = [
            ExportableImage(url: URL(fileURLWithPath: "/tmp/a.jpg")),
            ExportableImage(url: URL(fileURLWithPath: "/tmp/b.jpg")),
            ExportableImage(url: URL(fileURLWithPath: "/tmp/c.jpg"))
        ]
        let configuration = makeConfiguration()
        let sourceURLs = images.map { $0.url }
        let outputDirectory = configuration.outputDirectory
        let recorder = BatchEventRecorder()
        let cancellationController = ExportCancellationController()
        let startedFileNames = StartedFileNamesRecorder()
        let useCase = ExportImagesUseCase(
            exportImage: { sourceURL, _, _ in
                if sourceURL.lastPathComponent == "a.jpg" {
                    return ExportResult.success(
                        sourceURL: sourceURL,
                        outputURL: sourceURL.deletingPathExtension().appendingPathExtension("jpg"),
                        originalSize: CGSize(width: 4000, height: 3000),
                        exportedSize: CGSize(width: 2000, height: 1500),
                        fileSizeBytes: 1_024,
                        compressionQuality: 0.82
                    )
                }

                try? await Task.sleep(nanoseconds: 200_000_000)
                return ExportResult.success(
                    sourceURL: sourceURL,
                    outputURL: sourceURL.deletingPathExtension().appendingPathExtension("jpg"),
                    originalSize: CGSize(width: 4000, height: 3000),
                    exportedSize: CGSize(width: 2000, height: 1500),
                    fileSizeBytes: 1_024,
                    compressionQuality: 0.82
                )
            },
            concurrencyDecision: { _, _ in
                ExportBatchDecision(concurrency: 1, reason: "test")
            },
            preflightService: makePassingPreflightService(for: sourceURLs, outputDirectory: outputDirectory)
        )

        let summary = await useCase.execute(
            images: images,
            configuration: configuration,
            importedRootFolders: [],
            cancellationController: cancellationController
        ) { event in
            await recorder.record(event)
            if case let .started(_, fileName) = event {
                await startedFileNames.record(fileName)
            }
            if case let .completed(_, result, _) = event, result.sourceFileName == "a.jpg" {
                await cancellationController.cancel()
            }
        }

        let startedNames = await startedFileNames.values
        let events = await recorder.events
        let finishedSummary = events.compactMap { event -> ExportBatchSummary? in
            guard case let .finished(summary) = event else { return nil }
            return summary
        }.last

        XCTAssertEqual(startedNames, ["a.jpg"])
        XCTAssertEqual(summary.successCount, 1)
        XCTAssertEqual(summary.failureCount, 0)
        XCTAssertEqual(summary.skippedCount, 0)
        XCTAssertTrue(summary.wasCancelled)
        XCTAssertTrue(finishedSummary?.wasCancelled == true)
    }

    func testExecuteSchedulesMultipleExportsConcurrently() async throws {
        let images = (0..<8).map {
            ExportableImage(url: URL(fileURLWithPath: "/tmp/\($0).jpg"))
        }
        let configuration = makeConfiguration()
        let sourceURLs = images.map { $0.url }
        let outputDirectory = configuration.outputDirectory
        let concurrencyProbe = ExportConcurrencyProbe()
        let useCase = ExportImagesUseCase(
            exportImage: { sourceURL, _, _ in
                await concurrencyProbe.started()
                defer {
                    Task { await concurrencyProbe.finished() }
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
                return ExportResult.success(
                    sourceURL: sourceURL,
                    outputURL: sourceURL.deletingPathExtension().appendingPathExtension("jpg"),
                    originalSize: CGSize(width: 4000, height: 3000),
                    exportedSize: CGSize(width: 2000, height: 1500),
                    fileSizeBytes: 1_024,
                    compressionQuality: 0.82
                )
            },
            concurrencyDecision: { _, _ in
                ExportBatchDecision(concurrency: 8, reason: "test")
            },
            preflightService: makePassingPreflightService(for: sourceURLs, outputDirectory: outputDirectory)
        )

        _ = await useCase.execute(
            images: images,
            configuration: configuration,
            importedRootFolders: []
        ) { _ in
            await MainActor.run {}
        }

        let maxInFlight = await concurrencyProbe.maxInFlight
        XCTAssertGreaterThan(maxInFlight, 1)
    }

    func testDiagnosticRealExporterOverlap() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let inputDirectory = temporaryDirectory.appendingPathComponent("input", isDirectory: true)
        let outputDirectory = temporaryDirectory.appendingPathComponent("output", isDirectory: true)
        try FileManager.default.createDirectory(at: inputDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let images = try (0..<8).map { index -> ExportableImage in
            let sourceURL = inputDirectory.appendingPathComponent("source-\(index).jpg")
            try makeJPEG(at: sourceURL, size: CGSize(width: 3200, height: 2400))
            return ExportableImage(url: sourceURL)
        }

        let configuration = ExportConfiguration(
            maxWidth: 1600,
            maxHeight: nil,
            maxLongEdge: nil,
            maxShortEdge: nil,
            maxFileSizeBytes: nil,
            outputDirectory: outputDirectory,
            overwriteExisting: true,
            preserveMetadata: true,
            createSubfolder: false,
            subfolderSuffix: "_小图"
        )
        let concurrencyProbe = ExportConcurrencyProbe()
        let exporter = ExportSingleImageUseCase()
        let useCase = ExportImagesUseCase(
            exportImage: { sourceURL, configuration, importedRootFolders in
                await concurrencyProbe.started()
                defer {
                    Task { await concurrencyProbe.finished() }
                }
                return await exporter.execute(
                    sourceURL: sourceURL,
                    configuration: configuration,
                    importedRootFolders: importedRootFolders
                )
            },
            concurrencyDecision: { _, _ in
                ExportBatchDecision(concurrency: 8, reason: "test")
            }
        )

        let summary = await useCase.execute(
            images: images,
            configuration: configuration,
            importedRootFolders: []
        ) { _ in
            await MainActor.run {}
        }

        let maxInFlight = await concurrencyProbe.maxInFlight
        XCTAssertEqual(summary.successCount, 8)
        XCTAssertGreaterThan(maxInFlight, 1)
    }

    private func makeConfiguration() -> ExportConfiguration {
        ExportConfiguration(
            maxWidth: nil,
            maxHeight: nil,
            maxLongEdge: nil,
            maxShortEdge: nil,
            maxFileSizeBytes: nil,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            overwriteExisting: true,
            preserveMetadata: true,
            createSubfolder: false,
            subfolderSuffix: "_小图"
        )
    }

    private func makePassingPreflightService(
        for sourceURLs: [URL],
        outputDirectory: URL
    ) -> OperationPreflightService {
        let existingPaths = Set(sourceURLs.map(\.path)).union([outputDirectory.path, "/tmp"])
        return OperationPreflightService(
            itemExists: { existingPaths.contains($0.path) },
            isWritable: { _ in true }
        )
    }

    private func makeJPEG(at url: URL, size: CGSize) throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "ImageExporterBatchExportUseCaseTests", code: 1)
        }

        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        guard let image = context.makeImage() else {
            throw NSError(domain: "ImageExporterBatchExportUseCaseTests", code: 2)
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw NSError(domain: "ImageExporterBatchExportUseCaseTests", code: 3)
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "ImageExporterBatchExportUseCaseTests", code: 4)
        }

        try data.write(to: url)
    }
}

private actor BatchEventRecorder {
    private var recordedEvents: [ExportBatchEvent] = []

    func record(_ event: ExportBatchEvent) {
        recordedEvents.append(event)
    }

    var events: [ExportBatchEvent] {
        recordedEvents
    }
}

private actor ExportConcurrencyProbe {
    private var currentInFlight = 0
    private(set) var maxInFlight = 0

    func started() {
        currentInFlight += 1
        maxInFlight = max(maxInFlight, currentInFlight)
    }

    func finished() {
        currentInFlight -= 1
    }
}

private actor StartedFileNamesRecorder {
    private var fileNames: [String] = []

    func record(_ fileName: String) {
        fileNames.append(fileName)
    }

    var values: [String] {
        fileNames
    }
}

private extension ExportBatchEvent {
    var isStarted: Bool {
        if case .started = self {
            return true
        }
        return false
    }

    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
}
