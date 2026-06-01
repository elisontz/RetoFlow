import AppKit
import SwiftUI
import UniformTypeIdentifiers
import Combine

@MainActor
class FileRenamerViewModel: ObservableObject {
    private let previewUseCase: GenerateRenamePreviewUseCase
    private let buildPlanUseCase: BuildRenameOperationPlanUseCase
    private let preflightService: OperationPreflightService
    private let applyRenameRulesUseCase: ApplyRenameRulesUseCase
    private let reportStore: TaskReportStore
    private let itemProviderResolver: ItemProviderFileURLResolver
    private let accessCoordinator: any SecurityScopedAccessing

    @Published var files: [RenamableFile] = []
    @Published var rules: [RenameRule] = []
    @Published var isProcessing: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""

    init(
        previewUseCase: GenerateRenamePreviewUseCase = GenerateRenamePreviewUseCase(),
        buildPlanUseCase: BuildRenameOperationPlanUseCase = BuildRenameOperationPlanUseCase(),
        preflightService: OperationPreflightService = OperationPreflightService(),
        applyRenameRulesUseCase: ApplyRenameRulesUseCase = ApplyRenameRulesUseCase(),
        reportStore: TaskReportStore = TaskReportStore(),
        itemProviderResolver: ItemProviderFileURLResolver = ItemProviderFileURLResolver(),
        accessCoordinator: any SecurityScopedAccessing = sharedSecurityScopedAccessCoordinator()
    ) {
        self.previewUseCase = previewUseCase
        self.buildPlanUseCase = buildPlanUseCase
        self.preflightService = preflightService
        self.applyRenameRulesUseCase = applyRenameRulesUseCase
        self.reportStore = reportStore
        self.itemProviderResolver = itemProviderResolver
        self.accessCoordinator = accessCoordinator
    }
    
    // MARK: - File Management
    
    func addFiles(_ providers: [NSItemProvider]) {
        Task {
            var collectedURLs: [URL] = []
            
            for provider in providers {
                if let url = await self.itemProviderResolver.resolve(from: provider) {
                    collectedURLs.append(url)
                }
            }
            let accessCoordinator = self.accessCoordinator

            let finalFiles = await Task.detached(priority: .userInitiated) {
                var finalFiles: [URL] = []
                let fileManager = FileManager.default

                for url in collectedURLs {
                    accessCoordinator.withAccess(to: url) {
                        var isDir: ObjCBool = false
                        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
                            if isDir.boolValue {
                                // 如果是文件夹，递归遍历
                                if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                                    while let fileURL = enumerator.nextObject() as? URL {
                                        var isInnerDir: ObjCBool = false
                                        if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isInnerDir), !isInnerDir.boolValue {
                                            finalFiles.append(fileURL)
                                        }
                                    }
                                }
                            } else {
                                // 如果是文件，直接添加
                                finalFiles.append(url)
                            }
                        }
                    }
                }

                return finalFiles
            }.value
            
            // 回到主线程更新 UI
            self.appendFiles(finalFiles)
        }
    }

    func selectFilesAndFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = String(localized: "选择要重命名的文件或文件夹")

        guard panel.runModal() == .OK else { return }

        accessCoordinator.register(urls: panel.urls)
        let providers = panel.urls.map(NSItemProvider.init(contentsOf:)).compactMap { $0 }
        addFiles(providers)
    }
    
    @MainActor
    private func appendFiles(_ newFiles: [URL]) {
        var added = false
        for url in newFiles {
            // 避免重复添加
            if !files.contains(where: { $0.originalURL == url }) {
                let file = RenamableFile(originalURL: url, newFilename: url.lastPathComponent)
                files.append(file)
                added = true
            }
        }
        
        if added {
            updatePreview()
        }
    }
    
    func removeFiles(at offsets: IndexSet) {
        files.remove(atOffsets: offsets)
        updatePreview() // 重新生成预览，因为序列号可能改变
    }
    
    func removeFiles(with ids: Set<UUID>) {
        files.removeAll { ids.contains($0.id) }
        updatePreview()
    }
    
    func clearFiles() {
        files.removeAll()
    }
    
    // MARK: - Rule Management
    
    func addRule(_ type: RenameRuleType) {
        rules.append(RenameRule.defaultRule(type))
        updatePreview()
    }
    
    func removeRule(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
        updatePreview()
    }
    
    func moveRule(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        updatePreview()
    }
    
    func deleteRule(_ rule: RenameRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules.remove(at: index)
            updatePreview()
        }
    }
    
    func ruleDidChange() {
        updatePreview(debounced: true)
    }
    
    // MARK: - Preview Logic
    
    private var previewTask: Task<Void, Never>?
    
    func updatePreview(debounced: Bool = false) {
        previewTask?.cancel()
        
        previewTask = Task {
            if debounced {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            }
            
            if Task.isCancelled { return }
            
            let currentFiles = self.files
            let currentRules = self.rules
            let previewUseCase = self.previewUseCase
            let buildPlanUseCase = self.buildPlanUseCase
            let preflightService = self.preflightService
            
            let updatedFiles = await Task.detached(priority: .userInitiated) {
                let previewFiles = previewUseCase.execute(files: currentFiles, rules: currentRules)
                let plan = buildPlanUseCase.execute(files: previewFiles)
                let preflightResults = preflightService.evaluate(plan)
                return Self.applyPreflightStatuses(previewFiles, plan: plan, statuses: preflightResults)
            }.value
            
            if !Task.isCancelled {
                self.files = updatedFiles
            }
        }
    }

    nonisolated private static func applyPreflightStatuses(
        _ files: [RenamableFile],
        plan: OperationPlan,
        statuses: [UUID: PreflightStatus]
    ) -> [RenamableFile] {
        let filesBySource = Dictionary(uniqueKeysWithValues: plan.operations.map { ($0.sourceURL, $0.id) })
        var updatedFiles = files

        for index in updatedFiles.indices {
            updatedFiles[index].error = nil

            guard let operationID = filesBySource[updatedFiles[index].originalURL],
                  let status = statuses[operationID] else {
                continue
            }

            switch status {
            case .ready:
                break
            case .warning(let issues), .blocked(let issues):
                updatedFiles[index].error = issues.map(\.localizedDescription).joined(separator: "\n")
            }
        }

        return updatedFiles
    }
    
    // MARK: - Execution
    
    func applyRenaming() async {
        isProcessing = true
        defer { isProcessing = false }

        let result = await applyRenameRulesUseCase.execute(files: files)
        files = result.updatedFiles
        let report = TaskReport(
            taskKind: "file-renamer",
            startedAt: Date(),
            endedAt: Date(),
            successCount: result.successCount,
            skippedCount: result.skippedCount,
            failedCount: result.failureCount,
            records: result.records
        )
        _ = try? reportStore.save(report)
        alertMessage = TaskReportPresentation(report: report).message
        showAlert = true
    }
}
