import XCTest
@testable import RetoFlow

final class FileRenamerOperationPlanTests: XCTestCase {
    func testBuildRenameOperationPlanCreatesSourceDestinationPairsForRenamedFiles() {
        let unchangedURL = URL(fileURLWithPath: "/tmp/keep.txt")
        let renamedURL = URL(fileURLWithPath: "/tmp/original.txt")
        let files = [
            RenamableFile(originalURL: unchangedURL, newFilename: "keep.txt"),
            RenamableFile(originalURL: renamedURL, newFilename: "renamed.txt")
        ]

        let useCase = BuildRenameOperationPlanUseCase()

        let plan = useCase.execute(files: files)

        XCTAssertEqual(plan.taskKind, "file-renamer")
        XCTAssertEqual(plan.operations.count, 1)
        XCTAssertEqual(plan.operations.first?.kind, .rename)
        XCTAssertEqual(plan.operations.first?.sourceURL, renamedURL)
        XCTAssertEqual(plan.operations.first?.destinationURL, renamedURL.deletingLastPathComponent().appendingPathComponent("renamed.txt"))
    }
}
