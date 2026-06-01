import Foundation

struct OrganizeEditedImagesUseCase: Sendable {
    private let buildPlanUseCase: BuildOrganizeOperationPlanUseCase
    private let preflightService: OperationPreflightService
    private let taskExecutionCenter: TaskExecutionCenter

    nonisolated init(
        fileOperations: EditedImageFileOperations = EditedImageFileOperations(),
        buildPlanUseCase: BuildOrganizeOperationPlanUseCase = BuildOrganizeOperationPlanUseCase(),
        preflightService: OperationPreflightService = OperationPreflightService()
    ) {
        self.buildPlanUseCase = buildPlanUseCase
        self.preflightService = preflightService
        self.taskExecutionCenter = TaskExecutionCenter(
            fileAccessCoordinator: EditedImageFileAccessCoordinator(fileOperations: fileOperations)
        )
    }

    nonisolated func execute(diffResults: [DiffResult], checkedRoot: URL, originalRoot: URL) async -> OrganizeImagesResult {
        let plan = buildPlanUseCase.execute(diffResults: diffResults, checkedRoot: checkedRoot, originalRoot: originalRoot)
        let preflightResults = preflightService.evaluate(plan)
        let report = await taskExecutionCenter.execute(plan: plan, preflightResults: preflightResults)
        let failures = report.records.compactMap(\.errorDescription)

        return OrganizeImagesResult(
            movedCount: report.successCount,
            skippedCount: report.skippedCount,
            failedCount: report.failedCount,
            failures: failures,
            records: report.records
        )
    }
}

private struct EditedImageFileAccessCoordinator: FileAccessCoordinating, Sendable {
    nonisolated private let fileOperations: EditedImageFileOperations

    nonisolated init(fileOperations: EditedImageFileOperations) {
        self.fileOperations = fileOperations
    }

    nonisolated func copyItem(at source: URL, to destination: URL) throws {
        throw FileAccessError.copyFailed(source: source, destination: destination)
    }

    nonisolated func moveItem(at source: URL, to destination: URL) throws {
        try fileOperations.moveItem(at: source, to: destination)
    }

    nonisolated func renameItem(at source: URL, to destination: URL) throws {
        try moveItem(at: source, to: destination)
    }

    nonisolated func trashItem(at source: URL) throws {
        throw FileAccessError.trashFailed(source)
    }

    nonisolated func ensureDirectoryExists(at url: URL) throws {
        try fileOperations.ensureDirectoryExists(at: url)
    }
}
