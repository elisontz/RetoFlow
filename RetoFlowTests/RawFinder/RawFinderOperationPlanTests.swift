import XCTest
@testable import RetoFlow

final class RawFinderOperationPlanTests: XCTestCase {
    func testBuildPlanCreatesTrashAndCopyOperationsForMatchedPair() {
        let imageURL = URL(fileURLWithPath: "/tmp/images/matched.jpg")
        let rawURL = URL(fileURLWithPath: "/tmp/raws/matched.arw")
        let match = RawMatchPair(imageURL: imageURL, rawURL: rawURL)

        let useCase = BuildRawReplacementOperationPlanUseCase()

        let plan = useCase.execute(matches: [match])

        XCTAssertEqual(plan.taskKind, "raw-replacement")
        XCTAssertEqual(plan.operations.count, 2)
        XCTAssertEqual(plan.operations.first?.kind, .trash)
        XCTAssertEqual(plan.operations.first?.sourceURL, imageURL)
        XCTAssertEqual(plan.operations.last?.kind, .copy)
        XCTAssertEqual(plan.operations.last?.sourceURL, rawURL)
        XCTAssertEqual(plan.operations.last?.destinationURL, imageURL.deletingLastPathComponent().appendingPathComponent(rawURL.lastPathComponent))
    }

    func testBuildPlanIgnoresMatchesWithoutRawFiles() {
        let imageURL = URL(fileURLWithPath: "/tmp/images/missing.jpg")
        let match = RawMatchPair(imageURL: imageURL, rawURL: nil)

        let useCase = BuildRawReplacementOperationPlanUseCase()

        let plan = useCase.execute(matches: [match])

        XCTAssertTrue(plan.isEmpty)
    }
}
