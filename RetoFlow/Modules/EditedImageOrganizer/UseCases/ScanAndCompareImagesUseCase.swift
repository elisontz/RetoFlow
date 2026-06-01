import Foundation

struct ScanAndCompareImagesResult: Sendable {
    let checkedFiles: [ImageFile]
    let originalFiles: [ImageFile]
    let diffResults: [DiffResult]
    let statusCounts: [DiffStatus: Int]
}

struct ScanAndCompareImagesUseCase: Sendable {
    private let scanner: EditedImageFileScanning

    nonisolated init(scanner: EditedImageFileScanning = EditedImageFileScanning()) {
        self.scanner = scanner
    }

    nonisolated func execute(checkedFolderURL: URL?, originalFolderURL: URL?) async throws -> ScanAndCompareImagesResult {
        let checkedFiles: [ImageFile]
        if let checkedFolderURL {
            checkedFiles = try await scanner.scan(folder: checkedFolderURL)
        } else {
            checkedFiles = []
        }

        let originalFiles: [ImageFile]
        if let originalFolderURL {
            originalFiles = try await scanner.scan(folder: originalFolderURL)
        } else {
            originalFiles = []
        }

        let diffResults: [DiffResult]
        if checkedFolderURL != nil, originalFolderURL != nil {
            diffResults = Comparator.compare(checked: checkedFiles, original: originalFiles)
        } else {
            diffResults = []
        }

        var statusCounts: [DiffStatus: Int] = [.match: 0, .mismatch: 0]
        for result in diffResults {
            statusCounts[result.status, default: 0] += 1
        }

        return ScanAndCompareImagesResult(
            checkedFiles: checkedFiles,
            originalFiles: originalFiles,
            diffResults: diffResults,
            statusCounts: statusCounts
        )
    }
}
