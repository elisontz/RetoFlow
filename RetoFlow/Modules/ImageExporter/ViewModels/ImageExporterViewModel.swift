import AppKit
import Combine
import SwiftUI

@MainActor
class ImageExporterViewModel: ObservableObject {
    private let importSourcesUseCase: ImportExportSourcesUseCase
    private let buildExportImageListUseCase: BuildExportImageListUseCase
    private let exportSingleImageUseCase: ExportSingleImageUseCase
    private let exportImagesUseCase: ExportImagesUseCase
    private let presentationMapper: ImageExportPresentationMapper
    private let reportStore: TaskReportStore
    private let configurationStore: ExportConfigurationStore
    private let accessCoordinator: any SecurityScopedAccessing
    private var currentExportTask: Task<Void, Never>?
    private var currentExportCancellationController: ExportCancellationController?
    private var currentExportSessionID = UUID()
    private var completedExportCount = 0
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties
    
    @Published var images: [ExportableImage] = []
    @Published var folders: [URL] = []  // 添加的文件夹列表
    @Published var directFiles: [URL] = []  // 直接添加的文件
    @Published var configuration: ExportConfiguration
    @Published var isExporting: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentFileName: String = ""
    @Published var selectedStatusFilter: ExportableImage.ExportStatus? = nil
    
    // 记录导入的根文件夹
    private var importedRootFolders: Set<URL> = []
    
    // 筛选后的图片列表
    var filteredImages: [ExportableImage] {
        guard let filter = selectedStatusFilter else { return images }
        return images.filter { $0.status == filter }
    }
    
    // 状态统计
    var statusCounts: [ExportableImage.ExportStatus: Int] {
        var counts: [ExportableImage.ExportStatus: Int] = [:]
        for image in images {
            counts[image.status, default: 0] += 1
        }
        return counts
    }
    
    // Alert states
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""

#if DEBUG
    @Published var debugLogs: [String] = []
#endif
    
    // MARK: - Initialization
    
    init(
        importSourcesUseCase: ImportExportSourcesUseCase = ImportExportSourcesUseCase(),
        buildExportImageListUseCase: BuildExportImageListUseCase = BuildExportImageListUseCase(),
        exportSingleImageUseCase: ExportSingleImageUseCase = ExportSingleImageUseCase(),
        exportImagesUseCase: ExportImagesUseCase = ExportImagesUseCase(),
        presentationMapper: ImageExportPresentationMapper = ImageExportPresentationMapper(),
        reportStore: TaskReportStore = TaskReportStore(),
        configurationStore: ExportConfigurationStore? = nil,
        accessCoordinator: any SecurityScopedAccessing = sharedSecurityScopedAccessCoordinator()
    ) {
        let resolvedConfigurationStore = configurationStore ?? ExportConfigurationStore()

        self.importSourcesUseCase = importSourcesUseCase
        self.buildExportImageListUseCase = buildExportImageListUseCase
        self.exportSingleImageUseCase = exportSingleImageUseCase
        self.exportImagesUseCase = exportImagesUseCase
        self.presentationMapper = presentationMapper
        self.reportStore = reportStore
        self.configurationStore = resolvedConfigurationStore
        self.accessCoordinator = accessCoordinator

        self.configuration = resolvedConfigurationStore.load(
            defaultOutputDirectory: FileManager.default.temporaryDirectory
        )

        $configuration
            .dropFirst()
            .sink { [resolvedConfigurationStore] configuration in
                resolvedConfigurationStore.save(configuration.normalizedDimensionLimits())
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// 更新配置
    func updateConfiguration(_ config: ExportConfiguration) {
        self.configuration = config
    }
    
    /// 添加图片文件
    func addImages(_ providers: [NSItemProvider]) {
        Task {
            let sources = await importSourcesUseCase.execute(providers: providers)
            let existingImages = self.images
            let existingFolders = self.folders
            let existingDirectFiles = self.directFiles
            let importedRootFolders = self.importedRootFolders
            let buildExportImageListUseCase = self.buildExportImageListUseCase

            // 卸载到后台线程执行 CPU 密集的文件扫描，避免阻塞主线程
            let result = await Task(priority: .userInitiated) {
                buildExportImageListUseCase.execute(
                    sources: sources,
                    existingImages: existingImages,
                    existingFolders: existingFolders,
                    existingDirectFiles: existingDirectFiles,
                    importedRootFolders: importedRootFolders
                )
            }.value

            self.images = result.images
            self.folders = result.folders
            self.directFiles = result.directFiles
            self.importedRootFolders = result.importedRootFolders
        }
    }

    func selectInputSources() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = String(localized: "选择要导出的图片或文件夹")

        guard panel.runModal() == .OK else { return }

        accessCoordinator.register(urls: panel.urls)
        let providers = panel.urls.map(NSItemProvider.init(contentsOf:)).compactMap { $0 }
        addImages(providers)
    }

    /// 移除文件夹
    func removeFolder(at index: Int) {
        guard folders.indices.contains(index) else { return }
        let removedFolder = folders[index]
        folders.remove(at: index)
        importedRootFolders.remove(removedFolder)
        
        // 移除该文件夹下的所有图片
        images.removeAll { image in
            image.url.path.hasPrefix(removedFolder.path)
        }
    }
    
    /// 清除直接添加的文件
    func clearDirectFiles() {
        // 移除直接添加的文件
        let directFileSet = Set(directFiles)
        images.removeAll { directFileSet.contains($0.url) }
        directFiles.removeAll()
    }
    
    /// 移除图片
    func removeImages(at offsets: IndexSet) {
        images.remove(atOffsets: offsets)
    }
    
    /// 移除指定图片
    func removeImage(_ image: ExportableImage) {
        images.removeAll { $0.id == image.id }
    }
    
    /// 清空所有
    func clearAll() {
        images.removeAll()
        folders.removeAll()
        directFiles.removeAll()
        importedRootFolders.removeAll()
        progress = 0.0
        currentFileName = ""
        completedExportCount = 0
        selectedStatusFilter = nil
#if DEBUG
        debugLogs.removeAll()
#endif
    }
    
    /// 选择筛选器
    func selectFilter(_ filter: ExportableImage.ExportStatus?) {
        selectedStatusFilter = filter
    }
    
    /// 选择输出目录
    func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "选择图片导出目录")
        
        if panel.runModal() == .OK, let url = panel.url {
            accessCoordinator.register(url: url)
            configuration.outputDirectory = url
        }
    }
    
    // MARK: - Export Logic
    
    /// 导出单个图片
    func exportSingleImage(_ sourceURL: URL) async -> ExportResult {
        return await exportSingleImageUseCase.execute(
            sourceURL: sourceURL,
            configuration: configuration,
            importedRootFolders: importedRootFolders
        )
    }
    
    /// 开始批量导出
    func startExport() {
        // 纯内存验证（不涉及文件系统），可在主线程同步执行
        let quickValidation = configuration.validateWithoutIO()
        guard quickValidation.isValid else {
            alertMessage = presentationMapper.makeValidationFailurePresentation(quickValidation).message
            showAlert = true
            return
        }

        guard !images.isEmpty else {
            alertMessage = presentationMapper.makeEmptySelectionPresentation().message
            showAlert = true
            return
        }

        isExporting = true
        progress = 0.0
        currentFileName = ""
        completedExportCount = 0

        let totalCount = images.count
        let configSnapshot = configuration
        let rootFoldersSnapshot = importedRootFolders
        let modeRawValue = UserDefaults.standard.string(forKey: "exportConcurrencyMode") ?? ExportConcurrencyMode.auto.rawValue
        let selectedMode = ExportConcurrencyMode(rawValue: modeRawValue) ?? .auto
        let cancellationController = ExportCancellationController()
        let sessionID = UUID()
        currentExportSessionID = sessionID
        currentExportCancellationController = cancellationController
        currentExportTask?.cancel()
        currentExportTask = Task { [weak self] in
            guard let self else { return }

            // 文件系统验证在后台执行，避免阻塞主线程
            let fullValidation = await Task(priority: .userInitiated) {
                configSnapshot.validate()
            }.value

            guard fullValidation.isValid else {
                await MainActor.run {
                    self.isExporting = false
                    self.alertMessage = self.presentationMapper.makeValidationFailurePresentation(fullValidation).message
                    self.showAlert = true
                }
                return
            }

            let summary = await self.exportImagesUseCase.execute(
                images: self.images,
                configuration: configSnapshot,
                importedRootFolders: rootFoldersSnapshot,
                mode: selectedMode,
                cancellationController: cancellationController
            ) { event in
                await MainActor.run {
                    self.handleBatchEvent(event, totalCount: totalCount)
                }
            }

            await MainActor.run {
                guard self.currentExportSessionID == sessionID else { return }
                self.finishExport(summary: summary)
            }
        }
    }
    
    /// 取消导出
    func cancelExport() {
        pushDebugLog("导出已取消")
        currentExportTask?.cancel()
        let controller = currentExportCancellationController
        Task {
            await controller?.cancel()
        }
    }
    
    // MARK: - Helper Methods

    private func handleBatchEvent(_ event: ExportBatchEvent, totalCount: Int) {
        switch event {
        case .started(let index, let fileName):
            guard images.indices.contains(index) else { return }
            images[index].status = .exporting
            currentFileName = fileName
        case .completed(let index, let result, let elapsed):
            guard images.indices.contains(index) else { return }
            if result.success {
                images[index].status = .success
                images[index].exportedSize = result.exportedSize
                images[index].fileSizeBytes = result.fileSizeBytes
                images[index].compressionQuality = result.compressionQuality
                images[index].error = nil
            } else {
                images[index].status = .failed
                images[index].error = result.error
            }

            completedExportCount += 1
            if !result.success {
                pushDebugLog("任务失败: \(images[index].fileName), 耗时=\(Int(elapsed * 1000))ms")
            } else if completedExportCount % 12 == 0 || completedExportCount == totalCount {
                pushDebugLog("进度采样: completed=\(completedExportCount)/\(totalCount), 耗时=\(Int(elapsed * 1000))ms")
            }
        case .progress(let completedCount, let totalCount):
            progress = Double(completedCount) / Double(totalCount)
        case .finished:
            break
        }
    }

    private func finishExport(summary: ExportBatchSummary) {
        isExporting = false
        currentFileName = ""
        completedExportCount = 0
        currentExportTask = nil
        currentExportCancellationController = nil

        let report = TaskReport(summary: summary)
        _ = try? reportStore.save(report)

        pushDebugLog(summary.concurrencyReason)
        pushDebugLog("并发策略: 本轮固定并发=\(summary.targetConcurrency)（导出过程中不再动态调整）")

        if summary.wasCancelled {
            resetInFlightImagesToPending()
            let unfinishedCount = images.filter { $0.status == .pending }.count
            let presentation = presentationMapper.makeCompletionPresentation(
                summary: summary,
                unfinishedCount: unfinishedCount
            )
            pushDebugLog(presentation.debugSummary)
            alertMessage = TaskReportPresentation(report: report).message
            showAlert = true
            return
        }

        let presentation = TaskReportPresentation(report: report)
        pushDebugLog(presentation.debugSummary)
        alertMessage = presentation.message
        showAlert = true
    }

    private func resetInFlightImagesToPending() {
        for index in images.indices where images[index].status == .exporting {
            images[index].status = .pending
            images[index].error = nil
            images[index].exportedSize = nil
            images[index].fileSizeBytes = nil
            images[index].compressionQuality = nil
        }
    }

    private func pushDebugLog(_ message: String) {
#if DEBUG
        let debugEnabled = UserDefaults.standard.bool(forKey: "enableExporterDebugLogs")
        guard debugEnabled else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let stamped = "[\(formatter.string(from: Date()))] \(message)"
        debugLogs.append(stamped)
        if debugLogs.count > 80 {
            debugLogs.removeFirst(debugLogs.count - 80)
        }
#else
        _ = message
#endif
    }

#if DEBUG
    func copyDebugLogsToClipboard() {
        let content = debugLogs.joined(separator: "\n")
        guard !content.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        pushDebugLog("已复制调试日志到剪贴板")
    }
#endif
}
