import Foundation

struct ScanAndMatchRawFilesResult: Sendable {
    let imageFiles: [URL]
    let rawFiles: [URL]
    let matches: [RawMatchPair]
    let statusCounts: [MatchStatus: Int]
}

struct ScanAndMatchRawFilesUseCase: Sendable {
    private let scanner: RawFileScanning
    private let imageExtensions = Set(["jpg", "jpeg", "png", "heic", "tif", "tiff", "webp"])
    private let rawExtensions = Set(["arw", "cr2", "cr3", "nef", "dng", "raf", "orf", "rw2", "pef", "srw", "3fr", "fff", "iiq", "k25", "kdc", "mef", "mos", "mrw", "rwl", "sr2", "srf", "x3f"])

    nonisolated init(scanner: RawFileScanning = RawFileScanning()) {
        self.scanner = scanner
    }

    nonisolated func execute(imageFolders: [URL], rawFolders: [URL], directImageFiles: [URL]) async -> ScanAndMatchRawFilesResult {
        async let scannedImages = scanner.scan(folders: imageFolders, supportedExtensions: imageExtensions)
        async let scannedRaws = scanner.scan(folders: rawFolders, supportedExtensions: rawExtensions)

        let imageFiles = Array(Set(await scannedImages + directImageFiles)).sorted(by: { $0.path < $1.path })
        let rawFiles = await scannedRaws

        var rawMap: [String: URL] = [:]
        for url in rawFiles {
            rawMap[url.deletingPathExtension().lastPathComponent.lowercased()] = url
        }

        let matches = imageFiles.map { imageURL in
            let key = imageURL.deletingPathExtension().lastPathComponent.lowercased()
            return RawMatchPair(imageURL: imageURL, rawURL: rawMap[key])
        }

        var statusCounts: [MatchStatus: Int] = [.matched: 0, .missing: 0]
        for match in matches {
            statusCounts[match.status, default: 0] += 1
        }

        return ScanAndMatchRawFilesResult(
            imageFiles: imageFiles,
            rawFiles: rawFiles,
            matches: matches,
            statusCounts: statusCounts
        )
    }
}
