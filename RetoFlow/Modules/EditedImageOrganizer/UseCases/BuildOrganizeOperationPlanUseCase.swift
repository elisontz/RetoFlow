import Foundation

struct BuildOrganizeOperationPlanUseCase: Sendable {
    nonisolated init() {}

    nonisolated func execute(diffResults: [DiffResult], checkedRoot: URL, originalRoot: URL) -> OperationPlan {
        let operations = diffResults.compactMap { result -> PlannedOperation? in
            switch result.status {
            case .match:
                guard let checkedFile = result.checkedFile, let originalFile = result.originalFile else {
                    return nil
                }

                let relativePath = originalFile.url.path.replacingOccurrences(of: originalRoot.path, with: "")
                let destinationURL = URL(fileURLWithPath: checkedRoot.path + relativePath)
                guard checkedFile.url.path != destinationURL.path else {
                    return nil
                }

                return PlannedOperation(
                    kind: .move,
                    sourceURL: checkedFile.url,
                    destinationURL: destinationURL,
                    riskLevel: .low,
                    recoverability: .reversible
                )

            case .mismatch:
                guard let checkedFile = result.checkedFile, result.originalFile == nil else {
                    return nil
                }

                let destinationURL = checkedRoot
                    .appendingPathComponent("未整理", isDirectory: true)
                    .appendingPathComponent(checkedFile.filename)
                guard checkedFile.url.path != destinationURL.path else {
                    return nil
                }

                return PlannedOperation(
                    kind: .move,
                    sourceURL: checkedFile.url,
                    destinationURL: destinationURL,
                    riskLevel: .medium,
                    recoverability: .reversible
                )
            }
        }

        return OperationPlan(taskKind: "edited-image-organizer", operations: operations)
    }
}
