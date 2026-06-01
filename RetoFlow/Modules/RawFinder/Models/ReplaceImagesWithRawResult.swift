import Foundation

struct ReplaceImagesWithRawResult: Sendable {
    let removedImageURLs: [URL]
    let successCount: Int
    let failureCount: Int
    let skippedCount: Int
    let records: [OperationRecord]
}

