import SwiftUI
import UniformTypeIdentifiers
import Foundation
import AppKit
import Combine

@MainActor
class RawFinderViewModel: ObservableObject {
    private let scanAndMatchUseCase: ScanAndMatchRawFilesUseCase
    private let buildRawReplacementPlanUseCase: BuildRawReplacementOperationPlanUseCase
    private let preflightService: OperationPreflightService
    private let replaceImagesUseCase: ReplaceImagesWithRawUseCase
    private let taskExecutionCenter: TaskExecutionCenter
    private let reportStore: TaskReportStore
    private let itemProviderResolver: ItemProviderFileURLResolver
    private let accessCoordinator: any SecurityScopedAccessing

    @Published var imageFiles: [URL] = []
    @Published var rawFiles: [URL] = []
    @Published var imageFolders: [URL] = []
    @Published var rawFolders: [URL] = []
    @Published var directImageFiles: [URL] = []
    @Published var matches: [RawMatchPair] = []
    @Published var isProcessing: Bool = false
    @Published var selectedStatusFilter: MatchStatus? = nil
    
    // Alert States
    @Published var showReplaceConfirmation: Bool = false
    @Published var showReplaceResult: Bool = false
    @Published var replaceResultMessage: String = ""

    init(
        scanAndMatchUseCase: ScanAndMatchRawFilesUseCase = ScanAndMatchRawFilesUseCase(),
        buildRawReplacementPlanUseCase: BuildRawReplacementOperationPlanUseCase = BuildRawReplacementOperationPlanUseCase(),
        preflightService: OperationPreflightService = OperationPreflightService(),
        replaceImagesUseCase: ReplaceImagesWithRawUseCase = ReplaceImagesWithRawUseCase(),
        taskExecutionCenter: TaskExecutionCenter = TaskExecutionCenter(),
        reportStore: TaskReportStore = TaskReportStore(),
        itemProviderResolver: ItemProviderFileURLResolver = ItemProviderFileURLResolver(),
        accessCoordinator: any SecurityScopedAccessing = sharedSecurityScopedAccessCoordinator()
    ) {
        self.scanAndMatchUseCase = scanAndMatchUseCase
        self.buildRawReplacementPlanUseCase = buildRawReplacementPlanUseCase
        self.preflightService = preflightService
        self.replaceImagesUseCase = replaceImagesUseCase
        self.taskExecutionCenter = taskExecutionCenter
        self.reportStore = reportStore
        self.itemProviderResolver = itemProviderResolver
        self.accessCoordinator = accessCoordinator
    }
    
    var filteredMatches: [RawMatchPair] {
        guard let filter = selectedStatusFilter else { return matches }
        return matches.filter { $0.status == filter }
    }
    
    var statusCounts: [MatchStatus: Int] {
        var counts: [MatchStatus: Int] = [.matched: 0, .missing: 0]
        for match in matches {
            counts[match.status, default: 0] += 1
        }
        return counts
    }
    
    var commonImageFolder: URL? {
        imageFiles.first?.deletingLastPathComponent()
    }
    
    var commonRawFolder: URL? {
        rawFiles.first?.deletingLastPathComponent()
    }
    
    func selectFilter(_ filter: MatchStatus?) {
        selectedStatusFilter = filter
    }
    
    // MARK: - Folder Management
    
    func addImageFolders(_ providers: [NSItemProvider]) {
        processDroppedItems(providers) { [weak self] newFolders, newFiles in
            guard let self = self else { return }
            self.appendUniqueFolders(newFolders, to: &self.imageFolders)
            self.appendUniqueFiles(newFiles, to: &self.directImageFiles)
            self.triggerRescan()
        }
    }
    
    func addRawFolders(_ providers: [NSItemProvider]) {
        processDroppedItems(providers) { [weak self] newFolders, _ in
            guard let self = self else { return }
            self.appendUniqueFolders(newFolders, to: &self.rawFolders)
            // RAW 侧只支持文件夹，不支持直接拖入单个文件
            self.triggerRescan()
        }
    }

    func selectImageSources() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = String(localized: "选择小图或精选图文件/文件夹")

        guard panel.runModal() == .OK else { return }

        let urls = panel.urls
        accessCoordinator.register(urls: urls)
        var folders: [URL] = []
        var files: [URL] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                folders.append(url)
            } else {
                files.append(url)
            }
        }

        appendUniqueFolders(folders, to: &imageFolders)
        appendUniqueFiles(files, to: &directImageFiles)
        triggerRescan()
    }

    func selectRawFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = String(localized: "选择 RAW 文件库文件夹")

        guard panel.runModal() == .OK else { return }

        accessCoordinator.register(urls: panel.urls)
        appendUniqueFolders(panel.urls, to: &rawFolders)
        triggerRescan()
    }

    func removeImageFolder(at index: Int) {
        guard imageFolders.indices.contains(index) else { return }
        imageFolders.remove(at: index)
        triggerRescan()
    }
    
    func removeRawFolder(at index: Int) {
        guard rawFolders.indices.contains(index) else { return }
        rawFolders.remove(at: index)
        triggerRescan()
    }
    
    func clearDirectImageFiles() {
        directImageFiles.removeAll()
        triggerRescan()
    }
    
    private func appendUniqueFolders(_ newFolders: [URL], to target: inout [URL]) {
        for folder in newFolders {
            if !target.contains(folder) {
                target.append(folder)
            }
        }
    }

    private func appendUniqueFiles(_ newFiles: [URL], to target: inout [URL]) {
        for file in newFiles {
            if !target.contains(file) {
                target.append(file)
            }
        }
    }
    
    // MARK: - Scanning
    
    private func triggerRescan() {
        Task { [weak self] in
            guard let self else { return }
            await self.refreshMatches()
        }
    }
    
    private func processDroppedItems(_ providers: [NSItemProvider], completion: @escaping @MainActor ([URL], [URL]) -> Void) {
        Task { @MainActor in
            var folders: [URL] = []
            var files: [URL] = []
            
            for provider in providers {
                if let url = await self.itemProviderResolver.resolve(from: provider) {
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                        if isDir.boolValue {
                            folders.append(url)
                        } else {
                            files.append(url)
                        }
                    }
                }
            }

            completion(folders, files)
        }
    }
    
    
    func clearImages() {
        imageFolders.removeAll()
        directImageFiles.removeAll()
        imageFiles.removeAll()
        triggerRescan()
    }
    
    func clearRaws() {
        rawFolders.removeAll()
        rawFiles.removeAll()
        triggerRescan()
    }
    
    func clearAll() {
        imageFiles.removeAll()
        rawFiles.removeAll()
        imageFolders.removeAll()
        rawFolders.removeAll()
        directImageFiles.removeAll()
        matches.removeAll()
        selectedStatusFilter = nil
        replaceResultMessage = ""
        showReplaceConfirmation = false
        showReplaceResult = false
    }
    
    // MARK: - Matching Logic

    /// 公开的刷新入口，供 View 层调用
    func updateMatches() {
        triggerRescan()
    }
    
    // MARK: - Operations
    
    func copyMissingRawFilenames() {
        let missingNames = matches
            .filter { $0.status == .missing }
            .map { $0.imageName }
            .joined(separator: "\n")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(missingNames, forType: .string)
    }
    
    func copyMatchedRaws(to destination: URL) async throws {
        isProcessing = true
        defer { isProcessing = false }

        let plan = buildRawReplacementPlanUseCase.executeCopyOnly(matches: matches, to: destination)
        let preflightResults = preflightService.evaluate(plan)
        let report = await taskExecutionCenter.execute(plan: plan, preflightResults: preflightResults)
        if report.failedCount > 0 {
            throw RawFinderError.copyOperationFailed(failures: report.failedCount)
        }
    }

    func replaceMatchedImagesWithRaw() async {
        isProcessing = true
        defer { isProcessing = false }

        let result = await replaceImagesUseCase.execute(matches: matches)
        self.imageFiles.removeAll { result.removedImageURLs.contains($0) }
        await refreshMatches()
        let report = TaskReport(
            taskKind: "raw-replacement",
            startedAt: Date(),
            endedAt: Date(),
            successCount: result.successCount,
            skippedCount: result.skippedCount,
            failedCount: result.failureCount,
            records: result.records
        )
        _ = try? reportStore.save(report)
        self.replaceResultMessage = TaskReportPresentation(report: report).message
        self.showReplaceResult = true
    }

    private func refreshMatches() async {
        isProcessing = true
        defer { isProcessing = false }

        let result = await scanAndMatchUseCase.execute(
            imageFolders: imageFolders,
            rawFolders: rawFolders,
            directImageFiles: directImageFiles
        )

        imageFiles = result.imageFiles
        rawFiles = result.rawFiles
        let plan = buildRawReplacementPlanUseCase.execute(matches: result.matches)
        let executableImages = Set(plan.operations.filter { $0.kind == .trash }.map(\.sourceURL))
        let preflightResults = preflightService.evaluate(plan)

        matches = result.matches.map { match in
            guard let rawURL = match.rawURL else {
                return match
            }

            let targetURL = match.imageURL.deletingLastPathComponent().appendingPathComponent(rawURL.lastPathComponent)
            let copyOperation = plan.operations.first {
                $0.kind == .copy && $0.sourceURL == rawURL && $0.destinationURL == targetURL
            }

            guard executableImages.contains(match.imageURL),
                  let operation = copyOperation,
                  let status = preflightResults[operation.id],
                  case .ready = status else {
                return RawMatchPair(imageURL: match.imageURL, rawURL: nil)
            }

            return match
        }
    }
}
