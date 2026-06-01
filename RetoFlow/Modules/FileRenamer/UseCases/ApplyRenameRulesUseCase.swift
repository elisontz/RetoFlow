import Foundation

struct ApplyRenameRulesUseCase: Sendable {
    private let buildPlanUseCase: BuildRenameOperationPlanUseCase
    private let preflightService: OperationPreflightService
    private let taskExecutionCenter: TaskExecutionCenter

    nonisolated init(
        buildPlanUseCase: BuildRenameOperationPlanUseCase = BuildRenameOperationPlanUseCase(),
        preflightService: OperationPreflightService = OperationPreflightService(),
        taskExecutionCenter: TaskExecutionCenter = TaskExecutionCenter()
    ) {
        self.buildPlanUseCase = buildPlanUseCase
        self.preflightService = preflightService
        self.taskExecutionCenter = taskExecutionCenter
    }

    nonisolated func execute(files: [RenamableFile]) async -> ApplyRenameRulesResult {
        var updatedFiles = files
            let unchangedCount = files.filter { $0.newFilename == $0.originalURL.lastPathComponent }.count
            let plan = buildPlanUseCase.execute(files: files)
            let preflightResults = preflightService.evaluate(plan)
            let report = await taskExecutionCenter.execute(plan: plan, preflightResults: preflightResults)

            for index in updatedFiles.indices {
                updatedFiles[index].error = nil
            }

            for record in report.records {
                guard let index = updatedFiles.firstIndex(where: { $0.originalURL == record.sourceURL }) else {
                    continue
                }

                switch record.status {
                case .succeeded:
                    if let destinationURL = record.destinationURL {
                        updatedFiles[index] = RenamableFile(
                            originalURL: destinationURL,
                            newFilename: destinationURL.lastPathComponent
                        )
                    }
                case .skipped, .failed:
                    updatedFiles[index].error = record.errorDescription
                }
            }

            return ApplyRenameRulesResult(
                updatedFiles: updatedFiles,
                successCount: report.successCount,
                failureCount: report.failedCount,
            skippedCount: report.skippedCount + unchangedCount,
            records: report.records
        )
    }
}
