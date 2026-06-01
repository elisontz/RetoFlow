import XCTest
@testable import RetoFlow

final class OperationPreflightServiceTests: XCTestCase {
    func testEvaluateMarksOperationBlockedWhenSourceIsMissing() {
        let operation = PlannedOperation(
            kind: .copy,
            sourceURL: URL(fileURLWithPath: "/tmp/missing.txt"),
            destinationURL: URL(fileURLWithPath: "/tmp/output.txt"),
            riskLevel: .low,
            recoverability: .reversible
        )
        let service = OperationPreflightService(
            itemExists: { url in
                ["/tmp", "/tmp/output-parent"].contains(url.path)
            },
            isWritable: { _ in true }
        )

        let status = service.evaluate(operation)

        XCTAssertEqual(status, .blocked([.sourceMissing(operation.sourceURL)]))
    }

    func testEvaluateMarksOperationBlockedWhenDestinationAlreadyExists() {
        let destinationURL = URL(fileURLWithPath: "/tmp/existing-output.txt")
        let operation = PlannedOperation(
            kind: .move,
            sourceURL: URL(fileURLWithPath: "/tmp/source.txt"),
            destinationURL: destinationURL,
            riskLevel: .medium,
            recoverability: .reversible
        )
        let service = OperationPreflightService(
            itemExists: { url in
                url.path == operation.sourceURL.path || url.path == destinationURL.path
            },
            isWritable: { _ in true }
        )

        let status = service.evaluate(operation)

        XCTAssertEqual(status, .blocked([.destinationExists(destinationURL)]))
    }

    func testEvaluateMarksOperationReadyWhenSourceExistsAndDestinationIsWritable() {
        let operation = PlannedOperation(
            kind: .rename,
            sourceURL: URL(fileURLWithPath: "/tmp/source.txt"),
            destinationURL: URL(fileURLWithPath: "/tmp/renamed.txt"),
            riskLevel: .low,
            recoverability: .reversible
        )
        let service = OperationPreflightService(
            itemExists: { url in url.path == operation.sourceURL.path },
            isWritable: { _ in true }
        )

        let status = service.evaluate(operation)

        XCTAssertEqual(status, .ready)
    }

    func testEvaluatePlanReturnsPerOperationStatuses() {
        let blockedOperation = PlannedOperation(
            kind: .copy,
            sourceURL: URL(fileURLWithPath: "/tmp/source-a.txt"),
            destinationURL: URL(fileURLWithPath: "/tmp/existing-a.txt"),
            riskLevel: .medium,
            recoverability: .reversible
        )
        let readyOperation = PlannedOperation(
            kind: .trash,
            sourceURL: URL(fileURLWithPath: "/tmp/source-b.txt"),
            destinationURL: nil,
            riskLevel: .high,
            recoverability: .userRecoverable
        )
        let service = OperationPreflightService(
            itemExists: { url in
                [
                    blockedOperation.sourceURL.path,
                    blockedOperation.destinationURL?.path,
                    readyOperation.sourceURL.path
                ].compactMap { $0 }.contains(url.path)
            },
            isWritable: { _ in true }
        )

        let statuses = service.evaluate(
            OperationPlan(taskKind: "batch", operations: [blockedOperation, readyOperation])
        )

        XCTAssertEqual(statuses[blockedOperation.id], .blocked([.destinationExists(blockedOperation.destinationURL!)]))
        XCTAssertEqual(statuses[readyOperation.id], .ready)
    }

    func testEvaluateUsesScopedAccessForSourceAndDestinationPaths() {
        let destinationURL = URL(fileURLWithPath: "/tmp/session/output.jpg")
        let operation = PlannedOperation(
            kind: .copy,
            sourceURL: URL(fileURLWithPath: "/tmp/session/source.jpg"),
            destinationURL: destinationURL,
            riskLevel: .medium,
            recoverability: .reversible
        )
        let accessSpy = TestSecurityScopedAccessSpy()
        let service = OperationPreflightService(
            itemExists: { url in url.path == operation.sourceURL.path },
            isWritable: { _ in true },
            accessCoordinator: accessSpy
        )

        let status = service.evaluate(operation)

        XCTAssertEqual(status, .ready)
        XCTAssertEqual(
            accessSpy.accessedURLBatches.first,
            [
                operation.sourceURL.standardizedFileURL,
                destinationURL.standardizedFileURL,
                destinationURL.deletingLastPathComponent().standardizedFileURL
            ]
        )
    }
}
