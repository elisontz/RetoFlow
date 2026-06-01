import XCTest
@testable import RetoFlow

@MainActor
final class EditedImageOrganizerViewModelTests: XCTestCase {

    // MARK: - Filter Logic

    func testApplyFilterWithNilShowsAllResults() {
        let vm = EditedImageOrganizerViewModel()
        let results = sampleDiffResults()
        vm.diffResults = results
        vm.selectedStatusFilter = nil

        XCTAssertEqual(vm.filteredResults.count, results.count)
    }

    func testApplyFilterByMatchShowsOnlyMatches() {
        let vm = EditedImageOrganizerViewModel()
        vm.diffResults = sampleDiffResults()
        vm.selectedStatusFilter = .match

        let matchCount = vm.filteredResults.count
        XCTAssertTrue(matchCount > 0)
        XCTAssertTrue(vm.filteredResults.allSatisfy { $0.status == .match })
    }

    func testApplyFilterByMismatchShowsOnlyMismatches() {
        let vm = EditedImageOrganizerViewModel()
        vm.diffResults = sampleDiffResults()
        vm.selectedStatusFilter = .mismatch

        XCTAssertTrue(vm.filteredResults.allSatisfy { $0.status == .mismatch })
    }

    func testSelectFilterUpdatesFilteredResults() {
        let vm = EditedImageOrganizerViewModel()
        vm.diffResults = sampleDiffResults()

        vm.selectFilter(.match)
        let matchOnly = vm.filteredResults
        XCTAssertTrue(matchOnly.allSatisfy { $0.status == .match })

        vm.selectFilter(nil)
        XCTAssertEqual(vm.filteredResults.count, vm.diffResults.count)
    }

    // MARK: - Clear All

    func testClearAllResetsAllState() {
        let vm = EditedImageOrganizerViewModel()
        vm.checkedFolderURL = URL(fileURLWithPath: "/tmp/checked")
        vm.originalFolderURL = URL(fileURLWithPath: "/tmp/original")
        vm.diffResults = sampleDiffResults()
        vm.selectedStatusFilter = .match
        vm.isScanning = true
        vm.statusCounts = [.match: 5, .mismatch: 3]

        vm.clearAll()

        XCTAssertNil(vm.checkedFolderURL)
        XCTAssertNil(vm.originalFolderURL)
        XCTAssertTrue(vm.checkedFiles.isEmpty)
        XCTAssertTrue(vm.originalFiles.isEmpty)
        XCTAssertTrue(vm.diffResults.isEmpty)
        XCTAssertTrue(vm.filteredResults.isEmpty)
        XCTAssertFalse(vm.isScanning)
        XCTAssertNil(vm.selectedStatusFilter)
        XCTAssertEqual(vm.statusCounts[.match], 0)
        XCTAssertEqual(vm.statusCounts[.mismatch], 0)
    }

    // MARK: - Helpers

    private func sampleDiffResults() -> [DiffResult] {
        let a = ImageFile(filename: "A.jpg", url: URL(fileURLWithPath: "/a.jpg"))
        let b = ImageFile(filename: "B.jpg", url: URL(fileURLWithPath: "/b.jpg"))
        let c = ImageFile(filename: "C.jpg", url: URL(fileURLWithPath: "/c.jpg"))
        return [
            DiffResult(status: .match, checkedFile: a, originalFile: a),
            DiffResult(status: .mismatch, checkedFile: b, originalFile: nil),
            DiffResult(status: .mismatch, checkedFile: nil, originalFile: c),
        ]
    }
}
