import Foundation
import Darwin
import CoreGraphics

actor ExportCancellationController {
    private var isCancelled = false

    func cancel() {
        isCancelled = true
    }

    func cancelled() -> Bool {
        isCancelled
    }
}

struct ExportImagesUseCase: Sendable {
    private let buildPlanUseCase: BuildImageExportOperationPlanUseCase
    private let preflightService: OperationPreflightService
    private let exportImage: @Sendable (URL, ExportConfiguration, Set<URL>) async -> ExportResult
    private let concurrencyDecision: @Sendable (ExportConfiguration, ExportConcurrencyMode) async -> ExportBatchDecision

    nonisolated init(
        exportImage: @escaping @Sendable (URL, ExportConfiguration, Set<URL>) async -> ExportResult = {
            sourceURL,
            configuration,
            importedRootFolders in
            await ExportSingleImageUseCase().execute(
                sourceURL: sourceURL,
                configuration: configuration,
                importedRootFolders: importedRootFolders
            )
        },
        concurrencyDecision: @escaping @Sendable (ExportConfiguration, ExportConcurrencyMode) async -> ExportBatchDecision = {
            configuration,
            mode in
            let controller = AdaptiveConcurrencyController(configuration: configuration, mode: mode)
            return controller.initialDecision()
        },
        buildPlanUseCase: BuildImageExportOperationPlanUseCase = BuildImageExportOperationPlanUseCase(),
        preflightService: OperationPreflightService = OperationPreflightService()
    ) {
        self.buildPlanUseCase = buildPlanUseCase
        self.preflightService = preflightService
        self.exportImage = exportImage
        self.concurrencyDecision = concurrencyDecision
    }

    nonisolated func execute(
        images: [ExportableImage],
        configuration: ExportConfiguration,
        importedRootFolders: Set<URL>,
        mode: ExportConcurrencyMode = .auto,
        cancellationController: ExportCancellationController? = nil,
        onEvent: (ExportBatchEvent) async -> Void
    ) async -> ExportBatchSummary {
        let startedAt = Date()
        let totalCount = images.count
        let plan = buildPlanUseCase.execute(
            images: images,
            configuration: configuration,
            importedRootFolders: importedRootFolders
        )
        let preflightResults = normalizedPreflightResults(
            preflightService.evaluate(plan),
            configuration: configuration
        )

        let (skippedIndexes, runnableIndexes, operationBySource) = preflightAndPartition(
            images: images,
            plan: plan,
            preflightResults: preflightResults
        )

        let initialDecision = await concurrencyDecision(configuration, mode)
        let targetConcurrency = max(1, initialDecision.concurrency)

        guard totalCount > 0 else {
            let summary = ExportBatchSummary(
                totalCount: 0,
                successCount: 0,
                failureCount: 0,
                skippedCount: 0,
                targetConcurrency: targetConcurrency,
                concurrencyReason: initialDecision.reason,
                outputDirectorySummary: outputDirectorySummary(for: configuration),
                wasCancelled: false,
                startedAt: startedAt,
                endedAt: startedAt
            )
            await onEvent(.finished(summary: summary))
            return summary
        }

        let (initialSkippedCount, skippedRecords) = await emitSkippedEvents(
            skippedIndexes: skippedIndexes,
            images: images,
            operationBySource: operationBySource,
            preflightResults: preflightResults,
            onEvent: onEvent
        )

        let (successCount, failureCount, finalSkippedCount, wasCancelled, runRecords) = await runExportLoop(
            runnableIndexes: runnableIndexes,
            images: images,
            skippedCount: initialSkippedCount,
            targetConcurrency: targetConcurrency,
            configuration: configuration,
            importedRootFolders: importedRootFolders,
            operationBySource: operationBySource,
            cancellationController: cancellationController,
            onEvent: onEvent
        )

        let allRecords = skippedRecords + runRecords
        let summary = ExportBatchSummary(
            totalCount: totalCount,
            successCount: successCount,
            failureCount: failureCount,
            skippedCount: finalSkippedCount,
            targetConcurrency: targetConcurrency,
            concurrencyReason: initialDecision.reason,
            outputDirectorySummary: outputDirectorySummary(for: configuration),
            wasCancelled: wasCancelled,
            startedAt: startedAt,
            endedAt: Date(),
            records: allRecords
        )
        await onEvent(.finished(summary: summary))
        return summary
    }

    nonisolated private func preflightAndPartition(
        images: [ExportableImage],
        plan: OperationPlan,
        preflightResults: [UUID: PreflightStatus]
    ) -> (skippedIndexes: [Int], runnableIndexes: [Int], operationBySource: [URL: PlannedOperation]) {
        let operationBySource = Dictionary(uniqueKeysWithValues: plan.operations.map { ($0.sourceURL, $0) })
        let skippedIndexes = images.indices.filter { index in
            guard let operation = operationBySource[images[index].url],
                  let status = preflightResults[operation.id] else {
                return true
            }
            switch status {
            case .ready, .warning:
                return false
            case .blocked:
                return true
            }
        }
        let runnableIndexes = images.indices.filter { !skippedIndexes.contains($0) }
        return (skippedIndexes, runnableIndexes, operationBySource)
    }

    nonisolated private func emitSkippedEvents(
        skippedIndexes: [Int],
        images: [ExportableImage],
        operationBySource: [URL: PlannedOperation],
        preflightResults: [UUID: PreflightStatus],
        onEvent: (ExportBatchEvent) async -> Void
    ) async -> (skippedCount: Int, records: [OperationRecord]) {
        var records: [OperationRecord] = []

        for index in skippedIndexes {
            let sourceURL = images[index].url
            let operation = operationBySource[sourceURL]
            let error = operationBySource[sourceURL]
                .flatMap { preflightResults[$0.id] }
                .flatMap(Self.preflightDescription)
                ?? String(localized: "请选择输出目录")
            records.append(
                OperationRecord(
                    operationID: operation?.id ?? UUID(),
                    kind: operation?.kind ?? .exportJPEG,
                    sourceURL: sourceURL,
                    destinationURL: operation?.destinationURL,
                    status: .skipped,
                    errorDescription: error
                )
            )
            await onEvent(.completed(
                index: index,
                result: ExportResult.failure(
                    sourceURL: sourceURL,
                    originalSize: .zero,
                    error: error
                ),
                elapsed: 0
            ))
        }
        if images.count > 0 {
            await onEvent(.progress(completedCount: skippedIndexes.count, totalCount: images.count))
        }
        return (skippedIndexes.count, records)
    }

    nonisolated private func runExportLoop(
        runnableIndexes: [Int],
        images: [ExportableImage],
        skippedCount: Int,
        targetConcurrency: Int,
        configuration: ExportConfiguration,
        importedRootFolders: Set<URL>,
        operationBySource: [URL: PlannedOperation],
        cancellationController: ExportCancellationController?,
        onEvent: (ExportBatchEvent) async -> Void
    ) async -> (successCount: Int, failureCount: Int, skippedCount: Int, wasCancelled: Bool, records: [OperationRecord]) {
        var nextIndexToSchedule = 0
        var completedCount = skippedCount
        var inFlightCount = 0
        var successCount = 0
        var failureCount = 0
        var wasCancelled = false
        var records: [OperationRecord] = []

        await withTaskGroup(of: (Int, ExportResult, TimeInterval).self) { group in
            while inFlightCount < targetConcurrency && nextIndexToSchedule < runnableIndexes.count {
                if await cancellationController?.cancelled() == true {
                    wasCancelled = true
                    break
                }

                let index = runnableIndexes[nextIndexToSchedule]
                nextIndexToSchedule += 1
                inFlightCount += 1

                await onEvent(.started(index: index, fileName: images[index].fileName))

                let sourceURL = images[index].url
                let exportImage = self.exportImage
                group.addTask(priority: .userInitiated) {
                    let start = Date()
                    let result = await exportImage(sourceURL, configuration, importedRootFolders)
                    return (index, result, Date().timeIntervalSince(start))
                }
            }

            while let (index, result, elapsed) = await group.next() {
                inFlightCount -= 1

                if await cancellationController?.cancelled() == true {
                    wasCancelled = true
                    group.cancelAll()
                    break
                }

                if result.success {
                    successCount += 1
                } else {
                    failureCount += 1
                }
                let operation = operationBySource[result.sourceURL]
                records.append(
                    OperationRecord(
                        operationID: operation?.id ?? UUID(),
                        kind: operation?.kind ?? .exportJPEG,
                        sourceURL: result.sourceURL,
                        destinationURL: result.outputURL ?? operation?.destinationURL,
                        status: result.success ? .succeeded : .failed,
                        errorDescription: result.error
                    )
                )

                completedCount += 1
                await onEvent(.completed(index: index, result: result, elapsed: elapsed))
                await onEvent(.progress(completedCount: completedCount, totalCount: images.count))

                while inFlightCount < targetConcurrency && nextIndexToSchedule < runnableIndexes.count {
                    if await cancellationController?.cancelled() == true {
                        wasCancelled = true
                        group.cancelAll()
                        break
                    }

                    let nextIndex = runnableIndexes[nextIndexToSchedule]
                    nextIndexToSchedule += 1
                    inFlightCount += 1

                    await onEvent(.started(index: nextIndex, fileName: images[nextIndex].fileName))

                    let sourceURL = images[nextIndex].url
                    let exportImage = self.exportImage
                    group.addTask(priority: .userInitiated) {
                        let start = Date()
                        let result = await exportImage(sourceURL, configuration, importedRootFolders)
                        return (nextIndex, result, Date().timeIntervalSince(start))
                    }
                }
            }
        }

        return (successCount, failureCount, skippedCount, wasCancelled, records)
    }

    nonisolated private func outputDirectorySummary(for configuration: ExportConfiguration) -> String {
        configuration.createSubfolder ? String(localized: "原目录子文件夹") : configuration.outputDirectory.path
    }

    nonisolated private static func preflightDescription(_ status: PreflightStatus) -> String? {
        switch status {
        case .ready:
            return nil
        case .warning(let issues), .blocked(let issues):
            return issues.map(\.localizedDescription).joined(separator: "\n")
        }
    }

    nonisolated private func normalizedPreflightResults(
        _ statuses: [UUID: PreflightStatus],
        configuration: ExportConfiguration
    ) -> [UUID: PreflightStatus] {
        guard configuration.overwriteExisting else {
            return statuses
        }

        return statuses.mapValues { status in
            switch status {
            case .ready:
                return .ready
            case .warning(let issues):
                let remainingIssues = issues.filter { issue in
                    if case .destinationExists = issue {
                        return false
                    }
                    return true
                }
                return remainingIssues.isEmpty ? .ready : .warning(remainingIssues)
            case .blocked(let issues):
                let remainingIssues = issues.filter { issue in
                    if case .destinationExists = issue {
                        return false
                    }
                    return true
                }
                return remainingIssues.isEmpty ? .ready : .blocked(remainingIssues)
            }
        }
    }
}

private struct AdaptiveConcurrencyController: Sendable {
    private let concurrency: Int
    private let reason: String

    init(configuration: ExportConfiguration, mode: ExportConcurrencyMode) {
        let cpuCount = ProcessInfo.processInfo.activeProcessorCount
        let chipModel = Self.chipModelIdentifier()

        var base: Int
        var reasonParts: [String] = []

        if let fixed = mode.targetConcurrency {
            base = fixed
            reasonParts.append("手动模式=\(fixed)")
        } else {
            let isMaxChip = chipModel.lowercased().contains("max")
            base = Self.recommendedAutoConcurrency(cpuCount: cpuCount, chipModel: chipModel)
            reasonParts.append("自动模式(芯片=\(chipModel))")

            let eightGB: UInt64 = 8 * 1024 * 1024 * 1024
            if ProcessInfo.processInfo.physicalMemory < eightGB {
                base -= 1
                reasonParts.append("内存<8GB")
            }

            if configuration.maxFileSizeBytes != nil {
                if !isMaxChip {
                    base -= 1
                }
                base = min(base, 8)
                reasonParts.append(isMaxChip ? "启用大小限制(Max机型保持8)" : "启用大小限制")
            }

            if Self.isThermalStateHigh(ProcessInfo.processInfo.thermalState) {
                base -= 1
                reasonParts.append("温度状态高")
            }
        }

        let final = max(1, base)
        self.concurrency = final
        self.reason = "并发初始化=\(final), \(reasonParts.joined(separator: ", "))"
    }

    func initialDecision() -> ExportBatchDecision {
        ExportBatchDecision(concurrency: concurrency, reason: reason)
    }

    private static func isThermalStateHigh(_ state: ProcessInfo.ThermalState) -> Bool {
        switch state {
        case .serious, .critical:
            return true
        default:
            return false
        }
    }

    private static func recommendedAutoConcurrency(cpuCount: Int, chipModel: String) -> Int {
        let lower = chipModel.lowercased()

        if lower.contains("max") {
            return 8
        }
        if lower.contains("pro") {
            return 7
        }
        if lower.contains("m4") || lower.contains("m3") || lower.contains("m2") || lower.contains("m1") {
            return 6
        }
        if lower.contains("intel") {
            return max(3, min(6, cpuCount / 2))
        }

#if arch(arm64)
        return max(4, min(8, cpuCount / 2))
#else
        return max(3, min(6, cpuCount / 2))
#endif
    }

    private static func chipModelIdentifier() -> String {
        if let brand = sysctlString("machdep.cpu.brand_string"), !brand.isEmpty {
            return brand
        }
        if let model = sysctlString("hw.model"), !model.isEmpty {
            return model
        }
        return "Unknown"
    }

    private static func sysctlString(_ key: String) -> String? {
        var size: Int = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0 else {
            return nil
        }

        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &value, &size, nil, 0) == 0 else {
            return nil
        }

        let bytes = value.prefix { $0 != 0 }
        return String(decoding: bytes.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
