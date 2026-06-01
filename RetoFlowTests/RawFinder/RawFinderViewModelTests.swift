import XCTest
@testable import RetoFlow

@MainActor
final class RawFinderViewModelTests: XCTestCase {

    // MARK: - Filter Logic

    func testFilteredMatchesWithNoFilterReturnsAll() {
        let vm = makeViewModel()
        vm.matches = sampleMatches()
        vm.selectedStatusFilter = nil

        XCTAssertEqual(vm.filteredMatches.count, vm.matches.count)
    }

    func testFilteredMatchesByMatchedStatus() {
        let vm = makeViewModel()
        vm.matches = sampleMatches()
        vm.selectFilter(.matched)

        XCTAssertTrue(vm.filteredMatches.allSatisfy { $0.status == .matched })
        XCTAssertEqual(vm.filteredMatches.count, 2)
    }

    func testFilteredMatchesByMissingStatus() {
        let vm = makeViewModel()
        vm.matches = sampleMatches()
        vm.selectFilter(.missing)

        XCTAssertTrue(vm.filteredMatches.allSatisfy { $0.status == .missing })
        XCTAssertEqual(vm.filteredMatches.count, 1)
    }

    // MARK: - Status Counts

    func testStatusCountsCalculation() {
        let vm = makeViewModel()
        vm.matches = sampleMatches()

        let counts = vm.statusCounts
        XCTAssertEqual(counts[.matched], 2)
        XCTAssertEqual(counts[.missing], 1)
    }

    func testStatusCountsEmptyWhenNoMatches() {
        let vm = makeViewModel()
        vm.matches = []

        let counts = vm.statusCounts
        XCTAssertEqual(counts[.matched], 0)
        XCTAssertEqual(counts[.missing], 0)
    }

    // MARK: - Folder Management

    func testRemoveImageFolderAtValidIndex() {
        let vm = makeViewModel()
        vm.imageFolders = [
            URL(fileURLWithPath: "/folder1"),
            URL(fileURLWithPath: "/folder2"),
            URL(fileURLWithPath: "/folder3")
        ]

        vm.removeImageFolder(at: 1)

        XCTAssertEqual(vm.imageFolders.count, 2)
        XCTAssertEqual(vm.imageFolders[0].path, "/folder1")
        XCTAssertEqual(vm.imageFolders[1].path, "/folder3")
    }

    func testRemoveImageFolderAtInvalidIndexDoesNothing() {
        let vm = makeViewModel()
        vm.imageFolders = [URL(fileURLWithPath: "/folder1")]

        vm.removeImageFolder(at: 5) // out of bounds

        XCTAssertEqual(vm.imageFolders.count, 1)
    }

    func testRemoveRawFolderAtValidIndex() {
        let vm = makeViewModel()
        vm.rawFolders = [
            URL(fileURLWithPath: "/raw1"),
            URL(fileURLWithPath: "/raw2")
        ]

        vm.removeRawFolder(at: 0)

        XCTAssertEqual(vm.rawFolders.count, 1)
        XCTAssertEqual(vm.rawFolders[0].path, "/raw2")
    }

    func testClearDirectImageFilesRemovesAll() {
        let vm = makeViewModel()
        vm.directImageFiles = [
            URL(fileURLWithPath: "/file1.jpg"),
            URL(fileURLWithPath: "/file2.jpg")
        ]

        vm.clearDirectImageFiles()

        XCTAssertTrue(vm.directImageFiles.isEmpty)
    }

    // MARK: - Clear All

    func testClearAllResetsAllState() {
        let vm = makeViewModel()
        vm.imageFolders = [URL(fileURLWithPath: "/img")]
        vm.rawFolders = [URL(fileURLWithPath: "/raw")]
        vm.directImageFiles = [URL(fileURLWithPath: "/file.jpg")]
        vm.imageFiles = [URL(fileURLWithPath: "/file.jpg")]
        vm.rawFiles = [URL(fileURLWithPath: "/raw.cr3")]
        vm.matches = sampleMatches()
        vm.selectedStatusFilter = .matched
        vm.replaceResultMessage = "Done"
        vm.showReplaceConfirmation = true
        vm.showReplaceResult = true

        vm.clearAll()

        XCTAssertTrue(vm.imageFiles.isEmpty)
        XCTAssertTrue(vm.rawFiles.isEmpty)
        XCTAssertTrue(vm.imageFolders.isEmpty)
        XCTAssertTrue(vm.rawFolders.isEmpty)
        XCTAssertTrue(vm.directImageFiles.isEmpty)
        XCTAssertTrue(vm.matches.isEmpty)
        XCTAssertNil(vm.selectedStatusFilter)
        XCTAssertEqual(vm.replaceResultMessage, "")
        XCTAssertFalse(vm.showReplaceConfirmation)
        XCTAssertFalse(vm.showReplaceResult)
    }

    // MARK: - Copy Missing Filenames

    func testCopyMissingRawFilenamesCopiesOnlyMissing() {
        let vm = makeViewModel()
        vm.matches = sampleMatches()

        vm.copyMissingRawFilenames()

        let pasteboard = NSPasteboard.general
        let copied = pasteboard.string(forType: .string) ?? ""
        XCTAssertEqual(copied, "C.jpg")
    }

    // MARK: - Helpers

    private func makeViewModel() -> RawFinderViewModel {
        RawFinderViewModel()
    }

    private func sampleMatches() -> [RawMatchPair] {
        [
            RawMatchPair(imageURL: URL(fileURLWithPath: "/img/A.jpg"), rawURL: URL(fileURLWithPath: "/raw/A.CR3")),
            RawMatchPair(imageURL: URL(fileURLWithPath: "/img/B.jpg"), rawURL: URL(fileURLWithPath: "/raw/B.CR3")),
            RawMatchPair(imageURL: URL(fileURLWithPath: "/img/C.jpg"), rawURL: nil),
        ]
    }
}
