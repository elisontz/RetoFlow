import XCTest
@testable import RetoFlow

final class TaskReportStoreTests: XCTestCase {
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

    func testSavePersistsReportAsJSONInInjectedDirectory() throws {
        let report = TaskReport(
            taskKind: "file-renamer",
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 20),
            successCount: 2,
            skippedCount: 1,
            failedCount: 0,
            records: [
                OperationRecord(
                    operationID: UUID(),
                    kind: .rename,
                    sourceURL: URL(fileURLWithPath: "/tmp/a.txt"),
                    destinationURL: URL(fileURLWithPath: "/tmp/b.txt"),
                    status: .succeeded,
                    errorDescription: nil
                )
            ]
        )
        let store = TaskReportStore(baseDirectory: temporaryDirectory)

        let savedURL = try store.save(report)
        let data = try Data(contentsOf: savedURL)
        let decodedReport = try JSONDecoder().decode(TaskReport.self, from: data)

        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
        XCTAssertEqual(decodedReport.taskKind, report.taskKind)
        XCTAssertEqual(decodedReport.successCount, report.successCount)
        XCTAssertEqual(decodedReport.records.first?.destinationURL, report.records.first?.destinationURL)
    }

    @MainActor
    func testPresentationMapsCountsAndKeyPathsIntoSummary() {
        let report = TaskReport(
            taskKind: "image-exporter",
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 20),
            successCount: 3,
            skippedCount: 1,
            failedCount: 1,
            records: [
                OperationRecord(
                    operationID: UUID(),
                    kind: .exportJPEG,
                    sourceURL: URL(fileURLWithPath: "/tmp/source-a.jpg"),
                    destinationURL: URL(fileURLWithPath: "/exports/a.jpg"),
                    status: .succeeded,
                    errorDescription: nil
                ),
                OperationRecord(
                    operationID: UUID(),
                    kind: .exportJPEG,
                    sourceURL: URL(fileURLWithPath: "/tmp/source-b.jpg"),
                    destinationURL: URL(fileURLWithPath: "/exports/b.jpg"),
                    status: .failed,
                    errorDescription: "boom"
                )
            ]
        )

        let presentation = TaskReportPresentation(report: report)

        XCTAssertTrue(presentation.message.contains("成功: 3"))
        XCTAssertTrue(presentation.message.contains("跳过: 1"))
        XCTAssertTrue(presentation.message.contains("/exports"))
        XCTAssertTrue(presentation.debugSummary.contains("image-exporter"))
    }

    func testSaveDoesNotOverwriteReportsWrittenInSameSecond() throws {
        let report = TaskReport(
            taskKind: "file-renamer",
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 20),
            successCount: 1,
            skippedCount: 0,
            failedCount: 0,
            records: []
        )
        let store = TaskReportStore(baseDirectory: temporaryDirectory)

        let firstURL = try store.save(report)
        let secondURL = try store.save(report)

        XCTAssertNotEqual(firstURL, secondURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondURL.path))
    }

    func testInitFromExportBatchSummaryPreservesTimingAndRecords() {
        let startedAt = Date(timeIntervalSince1970: 100)
        let endedAt = Date(timeIntervalSince1970: 140)
        let record = OperationRecord(
            operationID: UUID(),
            kind: .exportJPEG,
            sourceURL: URL(fileURLWithPath: "/tmp/source.jpg"),
            destinationURL: URL(fileURLWithPath: "/tmp/out.jpg"),
            status: .failed,
            errorDescription: "boom"
        )
        let summary = ExportBatchSummary(
            totalCount: 1,
            successCount: 0,
            failureCount: 1,
            skippedCount: 0,
            targetConcurrency: 4,
            concurrencyReason: "test",
            outputDirectorySummary: "/tmp",
            wasCancelled: false,
            startedAt: startedAt,
            endedAt: endedAt,
            records: [record]
        )

        let report = TaskReport(summary: summary)

        XCTAssertEqual(report.taskKind, "image-exporter")
        XCTAssertEqual(report.startedAt, startedAt)
        XCTAssertEqual(report.endedAt, endedAt)
        XCTAssertEqual(report.failedCount, 1)
        XCTAssertEqual(report.records.count, 1)
        XCTAssertEqual(report.records.first?.destinationURL, record.destinationURL)
    }
}
