import XCTest
@testable import RetoFlow

@MainActor
final class TaskExecutionCenterTests: XCTestCase {
    func testExecuteRunsReadyOperationsSkipsBlockedAndSummarizesResults() async throws {
        let readyOperation = PlannedOperation(
            kind: .rename,
            sourceURL: URL(fileURLWithPath: "/tmp/source-a.txt"),
            destinationURL: URL(fileURLWithPath: "/tmp/renamed-a.txt"),
            riskLevel: .low,
            recoverability: .reversible
        )
        let blockedOperation = PlannedOperation(
            kind: .copy,
            sourceURL: URL(fileURLWithPath: "/tmp/source-b.txt"),
            destinationURL: URL(fileURLWithPath: "/tmp/existing-b.txt"),
            riskLevel: .medium,
            recoverability: .reversible
        )
        let plan = OperationPlan(taskKind: "batch-rename", operations: [readyOperation, blockedOperation])

        final class CoordinatorSpy: @unchecked Sendable, FileAccessCoordinating {
            var renamedPairs: [(URL, URL)] = []

            func copyItem(at source: URL, to destination: URL) throws {
                XCTFail("Copy should not run for blocked operations")
            }

            func moveItem(at source: URL, to destination: URL) throws {
                XCTFail("Move should not run in this test")
            }

            func renameItem(at source: URL, to destination: URL) throws {
                renamedPairs.append((source, destination))
            }

            func trashItem(at source: URL) throws {
                XCTFail("Trash should not run in this test")
            }

            func ensureDirectoryExists(at url: URL) throws {}
        }

        let coordinator = CoordinatorSpy()
        let executionCenter = TaskExecutionCenter(
            fileAccessCoordinator: coordinator,
            now: { Date(timeIntervalSince1970: 1_234) }
        )

        let report = await executionCenter.execute(
            plan: plan,
            preflightResults: [
                readyOperation.id: .ready,
                blockedOperation.id: .blocked([.destinationExists(blockedOperation.destinationURL!)])
            ]
        )

        XCTAssertEqual(coordinator.renamedPairs.count, 1)
        XCTAssertEqual(coordinator.renamedPairs.first?.0, readyOperation.sourceURL)
        XCTAssertEqual(coordinator.renamedPairs.first?.1, readyOperation.destinationURL)
        XCTAssertEqual(report.taskKind, "batch-rename")
        XCTAssertEqual(report.startedAt, Date(timeIntervalSince1970: 1_234))
        XCTAssertEqual(report.endedAt, Date(timeIntervalSince1970: 1_234))
        XCTAssertEqual(report.successCount, 1)
        XCTAssertEqual(report.skippedCount, 1)
        XCTAssertEqual(report.failedCount, 0)
        XCTAssertEqual(report.records.count, 2)
        XCTAssertEqual(report.records.first?.status, .succeeded)
        XCTAssertEqual(report.records.last?.status, .skipped)
    }

    func testExecuteRecordsFailuresPerOperation() async throws {
        let failingOperation = PlannedOperation(
            kind: .trash,
            sourceURL: URL(fileURLWithPath: "/tmp/source-a.txt"),
            destinationURL: nil,
            riskLevel: .high,
            recoverability: .userRecoverable
        )
        let plan = OperationPlan(taskKind: "cleanup", operations: [failingOperation])

        struct CoordinatorStub: FileAccessCoordinating {
            nonisolated func copyItem(at source: URL, to destination: URL) throws {}
            nonisolated func moveItem(at source: URL, to destination: URL) throws {}
            nonisolated func renameItem(at source: URL, to destination: URL) throws {}
            nonisolated func trashItem(at source: URL) throws {
                throw FileAccessError.trashFailed(source)
            }
            nonisolated func ensureDirectoryExists(at url: URL) throws {}
        }

        let executionCenter = TaskExecutionCenter(fileAccessCoordinator: CoordinatorStub())

        let report = await executionCenter.execute(
            plan: plan,
            preflightResults: [failingOperation.id: .ready]
        )

        XCTAssertEqual(report.successCount, 0)
        XCTAssertEqual(report.skippedCount, 0)
        XCTAssertEqual(report.failedCount, 1)
        XCTAssertEqual(report.records.count, 1)
        XCTAssertEqual(report.records.first?.status, .failed)
        XCTAssertNotNil(report.records.first?.errorDescription)
    }

    func testExecuteRunsWarningOperationsInsteadOfSkippingThem() async throws {
        let warningOperation = PlannedOperation(
            kind: .copy,
            sourceURL: URL(fileURLWithPath: "/tmp/source-a.txt"),
            destinationURL: URL(fileURLWithPath: "/tmp/output-a.txt"),
            riskLevel: .medium,
            recoverability: .reproducible
        )
        let plan = OperationPlan(taskKind: "copy-batch", operations: [warningOperation])

        final class CoordinatorSpy: @unchecked Sendable, FileAccessCoordinating {
            var copiedPairs: [(URL, URL)] = []

            func copyItem(at source: URL, to destination: URL) throws {
                copiedPairs.append((source, destination))
            }

            func moveItem(at source: URL, to destination: URL) throws {
                XCTFail("Move should not run in this test")
            }

            func renameItem(at source: URL, to destination: URL) throws {
                XCTFail("Rename should not run in this test")
            }

            func trashItem(at source: URL) throws {
                XCTFail("Trash should not run in this test")
            }

            func ensureDirectoryExists(at url: URL) throws {}
        }

        let coordinator = CoordinatorSpy()
        let executionCenter = TaskExecutionCenter(fileAccessCoordinator: coordinator)

        let report = await executionCenter.execute(
            plan: plan,
            preflightResults: [
                warningOperation.id: .warning([.destinationNotWritable(warningOperation.destinationURL!.deletingLastPathComponent())])
            ]
        )

        XCTAssertEqual(coordinator.copiedPairs.count, 1)
        XCTAssertEqual(coordinator.copiedPairs.first?.0, warningOperation.sourceURL)
        XCTAssertEqual(coordinator.copiedPairs.first?.1, warningOperation.destinationURL)
        XCTAssertEqual(report.successCount, 1)
        XCTAssertEqual(report.skippedCount, 0)
        XCTAssertEqual(report.failedCount, 0)
        XCTAssertEqual(report.records.first?.status, .succeeded)
    }

    func testExecuteEnsuresDestinationDirectoryExistsBeforeMove() async throws {
        let moveOperation = PlannedOperation(
            kind: .move,
            sourceURL: URL(fileURLWithPath: "/tmp/source-a.txt"),
            destinationURL: URL(fileURLWithPath: "/tmp/nested/output-a.txt"),
            riskLevel: .low,
            recoverability: .reversible
        )
        let plan = OperationPlan(taskKind: "organize", operations: [moveOperation])

        final class CoordinatorSpy: @unchecked Sendable, FileAccessCoordinating {
            var ensuredDirectories: [URL] = []
            var movedPairs: [(URL, URL)] = []

            func copyItem(at source: URL, to destination: URL) throws {
                XCTFail("Copy should not run in this test")
            }

            func moveItem(at source: URL, to destination: URL) throws {
                movedPairs.append((source, destination))
            }

            func renameItem(at source: URL, to destination: URL) throws {
                XCTFail("Rename should not run in this test")
            }

            func trashItem(at source: URL) throws {
                XCTFail("Trash should not run in this test")
            }

            func ensureDirectoryExists(at url: URL) throws {
                ensuredDirectories.append(url)
            }
        }

        let coordinator = CoordinatorSpy()
        let executionCenter = TaskExecutionCenter(fileAccessCoordinator: coordinator)

        let report = await executionCenter.execute(
            plan: plan,
            preflightResults: [moveOperation.id: .ready]
        )

        XCTAssertEqual(coordinator.ensuredDirectories, [moveOperation.destinationURL!.deletingLastPathComponent()])
        XCTAssertEqual(coordinator.movedPairs.count, 1)
        XCTAssertEqual(report.successCount, 1)
        XCTAssertEqual(report.failedCount, 0)
    }

    func testExecuteUsesScopedAccessForOperationURLs() async throws {
        let operation = PlannedOperation(
            kind: .rename,
            sourceURL: URL(fileURLWithPath: "/tmp/source-a.txt"),
            destinationURL: URL(fileURLWithPath: "/tmp/output/renamed-a.txt"),
            riskLevel: .low,
            recoverability: .reversible
        )
        let plan = OperationPlan(taskKind: "batch-rename", operations: [operation])

        final class CoordinatorSpy: @unchecked Sendable, FileAccessCoordinating {
            var renamedPairs: [(URL, URL)] = []

            func copyItem(at source: URL, to destination: URL) throws {}
            func moveItem(at source: URL, to destination: URL) throws {}
            func renameItem(at source: URL, to destination: URL) throws {
                renamedPairs.append((source, destination))
            }
            func trashItem(at source: URL) throws {}
            func ensureDirectoryExists(at url: URL) throws {}
        }

        let accessSpy = TestSecurityScopedAccessSpy()
        let executionCenter = TaskExecutionCenter(
            fileAccessCoordinator: CoordinatorSpy(),
            accessCoordinator: accessSpy
        )

        _ = await executionCenter.execute(
            plan: plan,
            preflightResults: [operation.id: .ready]
        )

        XCTAssertEqual(
            accessSpy.accessedURLBatches.first,
            [
                operation.sourceURL.standardizedFileURL,
                operation.destinationURL!.standardizedFileURL
            ]
        )
    }
}
