import XCTest
@testable import RetoFlow

final class EditedImageOrganizerOperationPlanTests: XCTestCase {
    func testBuildPlanMovesMatchedFilesIntoOriginalRelativePath() {
        let checkedRoot = URL(fileURLWithPath: "/tmp/checked", isDirectory: true)
        let originalRoot = URL(fileURLWithPath: "/tmp/original", isDirectory: true)
        let checkedURL = checkedRoot.appendingPathComponent("matched.jpg")
        let originalURL = originalRoot.appendingPathComponent("session/matched.jpg")
        let diffResults = [
            DiffResult(
                status: .match,
                checkedFile: ImageFile(filename: "matched.jpg", url: checkedURL),
                originalFile: ImageFile(filename: "matched.jpg", url: originalURL)
            )
        ]

        let useCase = BuildOrganizeOperationPlanUseCase()

        let plan = useCase.execute(diffResults: diffResults, checkedRoot: checkedRoot, originalRoot: originalRoot)

        XCTAssertEqual(plan.operations.count, 1)
        XCTAssertEqual(plan.operations.first?.kind, .move)
        XCTAssertEqual(plan.operations.first?.sourceURL, checkedURL)
        XCTAssertEqual(plan.operations.first?.destinationURL, checkedRoot.appendingPathComponent("session/matched.jpg"))
    }

    func testBuildPlanMovesMismatchedFilesIntoPendingFolder() {
        let checkedRoot = URL(fileURLWithPath: "/tmp/checked", isDirectory: true)
        let originalRoot = URL(fileURLWithPath: "/tmp/original", isDirectory: true)
        let checkedURL = checkedRoot.appendingPathComponent("extra.jpg")
        let diffResults = [
            DiffResult(
                status: .mismatch,
                checkedFile: ImageFile(filename: "extra.jpg", url: checkedURL),
                originalFile: nil
            )
        ]

        let useCase = BuildOrganizeOperationPlanUseCase()

        let plan = useCase.execute(diffResults: diffResults, checkedRoot: checkedRoot, originalRoot: originalRoot)

        XCTAssertEqual(plan.operations.count, 1)
        XCTAssertEqual(plan.operations.first?.destinationURL, checkedRoot.appendingPathComponent("未整理/extra.jpg"))
    }
}
