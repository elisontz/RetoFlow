import XCTest
@testable import RetoFlow

final class OperationPlanTests: XCTestCase {
    func testPlanStoresMixedOperationsAndSummarizesCounts() {
        let operations = [
            PlannedOperation(
                kind: .rename,
                sourceURL: URL(fileURLWithPath: "/tmp/source-a.jpg"),
                destinationURL: URL(fileURLWithPath: "/tmp/renamed-a.jpg"),
                riskLevel: .low,
                recoverability: .reversible
            ),
            PlannedOperation(
                kind: .move,
                sourceURL: URL(fileURLWithPath: "/tmp/source-b.jpg"),
                destinationURL: URL(fileURLWithPath: "/tmp/folder/source-b.jpg"),
                riskLevel: .medium,
                recoverability: .reversible
            ),
            PlannedOperation(
                kind: .trash,
                sourceURL: URL(fileURLWithPath: "/tmp/source-c.jpg"),
                destinationURL: nil,
                riskLevel: .high,
                recoverability: .userRecoverable
            )
        ]

        let plan = OperationPlan(taskKind: "rename-preview", operations: operations)

        XCTAssertFalse(plan.isEmpty)
        XCTAssertEqual(plan.operations, operations)
        XCTAssertEqual(plan.summary.totalCount, 3)
        XCTAssertEqual(plan.summary.countsByKind[.rename], 1)
        XCTAssertEqual(plan.summary.countsByKind[.move], 1)
        XCTAssertEqual(plan.summary.countsByKind[.trash], 1)
    }

    func testPlanPreservesPerItemMetadata() {
        let sourceURL = URL(fileURLWithPath: "/tmp/original.nef")
        let destinationURL = URL(fileURLWithPath: "/tmp/exports/original.jpg")
        let operation = PlannedOperation(
            kind: .exportJPEG,
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            riskLevel: .medium,
            recoverability: .reproducible
        )

        let plan = OperationPlan(taskKind: "jpeg-export", operations: [operation])

        XCTAssertEqual(plan.operations.first?.sourceURL, sourceURL)
        XCTAssertEqual(plan.operations.first?.destinationURL, destinationURL)
        XCTAssertEqual(plan.operations.first?.riskLevel, .medium)
        XCTAssertEqual(plan.operations.first?.recoverability, .reproducible)
    }
}
