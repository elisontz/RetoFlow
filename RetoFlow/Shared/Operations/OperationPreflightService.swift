import Foundation

struct OperationPreflightService: Sendable {
    private let itemExists: @Sendable (URL) -> Bool
    private let isWritable: @Sendable (URL) -> Bool
    private let accessCoordinator: any SecurityScopedAccessing

    nonisolated init(
        itemExists: @escaping @Sendable (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) },
        isWritable: @escaping @Sendable (URL) -> Bool = Self.defaultIsWritable,
        accessCoordinator: any SecurityScopedAccessing = sharedSecurityScopedAccessCoordinator()
    ) {
        self.itemExists = itemExists
        self.isWritable = isWritable
        self.accessCoordinator = accessCoordinator
    }

    nonisolated func evaluate(_ plan: OperationPlan) -> [UUID: PreflightStatus] {
        Dictionary(uniqueKeysWithValues: plan.operations.map { ($0.id, evaluate($0)) })
    }

    nonisolated func evaluate(_ operation: PlannedOperation) -> PreflightStatus {
        accessCoordinator.withAccess(
            to: [
                operation.sourceURL,
                operation.destinationURL,
                operation.destinationURL?.deletingLastPathComponent()
            ].compactMap { $0 }
        ) {
            var issues: [PreflightIssue] = []

            if !itemExists(operation.sourceURL) {
                issues.append(.sourceMissing(operation.sourceURL))
            }

            if let destinationURL = operation.destinationURL {
                if itemExists(destinationURL) {
                    issues.append(.destinationExists(destinationURL))
                } else {
                    let parentURL = destinationURL.deletingLastPathComponent()
                    if !isWritable(parentURL) {
                        issues.append(.destinationNotWritable(parentURL))
                    }
                }
            }

            if issues.isEmpty {
                return .ready
            }

            return .blocked(issues)
        }
    }

    nonisolated private static func defaultIsWritable(at url: URL) -> Bool {
        var candidate = url

        while !FileManager.default.fileExists(atPath: candidate.path) {
            let parent = candidate.deletingLastPathComponent()
            guard parent.path != candidate.path else {
                break
            }
            candidate = parent
        }

        return FileManager.default.isWritableFile(atPath: candidate.path)
    }
}
