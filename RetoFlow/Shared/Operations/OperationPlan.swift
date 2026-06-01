import Foundation

struct OperationPlan: Equatable, Codable, Sendable {
    nonisolated let taskKind: String
    nonisolated let operations: [PlannedOperation]

    nonisolated var summary: Summary {
        Summary(operations: operations)
    }

    nonisolated var isEmpty: Bool {
        operations.isEmpty
    }
}

extension OperationPlan {
    struct Summary: Equatable, Codable, Sendable {
        nonisolated let totalCount: Int
        nonisolated let countsByKind: [PlannedOperationKind: Int]

        nonisolated init(operations: [PlannedOperation]) {
            self.totalCount = operations.count
            self.countsByKind = Dictionary(
                operations.map(\.kind).map { ($0, 1) },
                uniquingKeysWith: +
            )
        }
    }
}
