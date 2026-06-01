import XCTest
@testable import RetoFlow

@MainActor
final class ComparatorTests: XCTestCase {
    func testCompareReturnsMismatchesBeforeMatchesSortedByFilename() async {
        let checked = [
            ImageFile(filename: "B.jpg", url: URL(fileURLWithPath: "/checked/B.jpg")),
            ImageFile(filename: "A.jpg", url: URL(fileURLWithPath: "/checked/A.jpg"))
        ]
        let original = [
            ImageFile(filename: "A.jpg", url: URL(fileURLWithPath: "/original/A.jpg")),
            ImageFile(filename: "C.jpg", url: URL(fileURLWithPath: "/original/C.jpg"))
        ]

        let results = Comparator.compare(checked: checked, original: original)

        XCTAssertEqual(results.map(\.displayName), ["B.jpg", "C.jpg", "A.jpg"])
        XCTAssertEqual(results.map(\.status), [.mismatch, .mismatch, .match])
    }
}
