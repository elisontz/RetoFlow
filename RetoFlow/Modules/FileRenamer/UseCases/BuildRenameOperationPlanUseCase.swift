import Foundation

struct BuildRenameOperationPlanUseCase: Sendable {
    nonisolated init() {}

    nonisolated func execute(files: [RenamableFile]) -> OperationPlan {
        let operations = files.compactMap { file -> PlannedOperation? in
            guard file.newFilename != file.originalURL.lastPathComponent else {
                return nil
            }

            return PlannedOperation(
                kind: .rename,
                sourceURL: file.originalURL,
                destinationURL: file.originalURL.deletingLastPathComponent().appendingPathComponent(file.newFilename),
                riskLevel: .low,
                recoverability: .reversible
            )
        }

        return OperationPlan(taskKind: "file-renamer", operations: operations)
    }
}
