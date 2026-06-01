import Foundation

struct BuildRawReplacementOperationPlanUseCase: Sendable {
    private let itemExists: @Sendable (URL) -> Bool
    private let accessCoordinator: any SecurityScopedAccessing

    nonisolated init(
        itemExists: @escaping @Sendable (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) },
        accessCoordinator: any SecurityScopedAccessing = sharedSecurityScopedAccessCoordinator()
    ) {
        self.itemExists = itemExists
        self.accessCoordinator = accessCoordinator
    }

    nonisolated func execute(matches: [RawMatchPair]) -> OperationPlan {
        var operations: [PlannedOperation] = []

        for match in matches {
            guard let rawURL = match.rawURL else {
                continue
            }

            let targetURL = match.imageURL.deletingLastPathComponent().appendingPathComponent(rawURL.lastPathComponent)
            let targetExists = accessCoordinator.withAccess(to: targetURL) {
                itemExists(targetURL)
            }
            guard !targetExists else {
                continue
            }

            operations.append(
                PlannedOperation(
                    kind: .trash,
                    sourceURL: match.imageURL,
                    destinationURL: nil,
                    riskLevel: .high,
                    recoverability: .userRecoverable
                )
            )
            operations.append(
                PlannedOperation(
                    kind: .copy,
                    sourceURL: rawURL,
                    destinationURL: targetURL,
                    riskLevel: .medium,
                    recoverability: .reproducible
                )
            )
        }

        return OperationPlan(taskKind: "raw-replacement", operations: operations)
    }

    nonisolated func executeCopyOnly(matches: [RawMatchPair], to destination: URL) -> OperationPlan {
        var operations: [PlannedOperation] = []

        for match in matches {
            guard let rawURL = match.rawURL else { continue }

            let targetURL = destination.appendingPathComponent(rawURL.lastPathComponent)
            let targetExists = accessCoordinator.withAccess(to: targetURL) {
                itemExists(targetURL)
            }
            guard !targetExists else { continue }

            operations.append(
                PlannedOperation(
                    kind: .copy,
                    sourceURL: rawURL,
                    destinationURL: targetURL,
                    riskLevel: .low,
                    recoverability: .reproducible
                )
            )
        }

        return OperationPlan(taskKind: "raw-copy", operations: operations)
    }
}
