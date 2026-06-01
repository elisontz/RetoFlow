import Foundation

struct ReplaceImagesWithRawUseCase: Sendable {
    private let buildPlanUseCase: BuildRawReplacementOperationPlanUseCase
    private let preflightService: OperationPreflightService
    private let taskExecutionCenter: TaskExecutionCenter

    nonisolated init(
        buildPlanUseCase: BuildRawReplacementOperationPlanUseCase = BuildRawReplacementOperationPlanUseCase(),
        preflightService: OperationPreflightService = OperationPreflightService(),
        taskExecutionCenter: TaskExecutionCenter = TaskExecutionCenter()
    ) {
        self.buildPlanUseCase = buildPlanUseCase
        self.preflightService = preflightService
        self.taskExecutionCenter = taskExecutionCenter
    }

    nonisolated func execute(matches: [RawMatchPair]) async -> ReplaceImagesWithRawResult {
        let plan = buildPlanUseCase.execute(matches: matches)
        let preflightResults = preflightService.evaluate(plan)
        let report = await taskExecutionCenter.execute(plan: plan, preflightResults: preflightResults)
        let removed = report.records
            .filter { $0.kind == .trash && $0.status == .succeeded }
            .map(\.sourceURL)

        let matchedPairs = matches.filter { $0.rawURL != nil }
        let plannedTargets = Set(plan.operations.compactMap { operation -> URL? in
            guard operation.kind == .copy, let destinationURL = operation.destinationURL else {
                return nil
            }
            return destinationURL
        })

        var successCount = 0
        var failureCount = 0
        var skippedCount = 0

        for match in matchedPairs {
            guard let rawURL = match.rawURL else { continue }
            let targetURL = match.imageURL.deletingLastPathComponent().appendingPathComponent(rawURL.lastPathComponent)

            guard plannedTargets.contains(targetURL) else {
                skippedCount += 1
                continue
            }

            let trashSucceeded = report.records.contains {
                $0.kind == .trash &&
                $0.sourceURL == match.imageURL &&
                $0.status == .succeeded
            }
            let copySucceeded = report.records.contains {
                $0.kind == .copy &&
                $0.sourceURL == rawURL &&
                $0.destinationURL == targetURL &&
                $0.status == .succeeded
            }
            let copyFailed = report.records.contains {
                $0.kind == .copy &&
                $0.sourceURL == rawURL &&
                $0.destinationURL == targetURL &&
                $0.status == .failed
            }

            if trashSucceeded && copySucceeded {
                successCount += 1
            } else if copyFailed {
                failureCount += 1
            } else {
                skippedCount += 1
            }
        }

        return ReplaceImagesWithRawResult(
            removedImageURLs: removed,
            successCount: successCount,
            failureCount: failureCount,
            skippedCount: skippedCount,
            records: report.records
        )
    }
}
