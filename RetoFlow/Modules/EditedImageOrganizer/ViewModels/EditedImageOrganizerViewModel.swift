import AppKit
import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
class EditedImageOrganizerViewModel: ObservableObject {
    private let scanAndCompareUseCase: ScanAndCompareImagesUseCase
    private let organizeImagesUseCase: OrganizeEditedImagesUseCase
    private let reportStore: TaskReportStore
    private let itemProviderResolver: ItemProviderFileURLResolver
    private let accessCoordinator: any SecurityScopedAccessing

    // 文件夹路径
    @Published var checkedFolderURL: URL?
    @Published var originalFolderURL: URL?
    
    // 扫描到的文件缓存
    @Published var checkedFiles: [ImageFile] = []
    @Published var originalFiles: [ImageFile] = []
    
    // 比对结果
    @Published var diffResults: [DiffResult] = []
    @Published var filteredResults: [DiffResult] = []
    
    // 界面状态
    @Published var isScanning: Bool = false
    @Published var selectedStatusFilter: DiffStatus? = nil {
        didSet {
            applyFilter()
        }
    }
    @Published var statusCounts: [DiffStatus: Int] = [.match: 0, .mismatch: 0]
    
    // Alert States
    @Published var showOrganizeConfirmation: Bool = false
    @Published var showOrganizeResult: Bool = false
    @Published var organizeResultMessage: String = ""

    init(
        scanAndCompareUseCase: ScanAndCompareImagesUseCase = ScanAndCompareImagesUseCase(),
        organizeImagesUseCase: OrganizeEditedImagesUseCase = OrganizeEditedImagesUseCase(),
        reportStore: TaskReportStore = TaskReportStore(),
        itemProviderResolver: ItemProviderFileURLResolver = ItemProviderFileURLResolver(),
        accessCoordinator: any SecurityScopedAccessing = sharedSecurityScopedAccessCoordinator()
    ) {
        self.scanAndCompareUseCase = scanAndCompareUseCase
        self.organizeImagesUseCase = organizeImagesUseCase
        self.reportStore = reportStore
        self.itemProviderResolver = itemProviderResolver
        self.accessCoordinator = accessCoordinator
    }
    
    // MARK: - Actions
    
    // 拖放处理
    func handleDropChecked(providers: [NSItemProvider]) -> Bool {
        return handleDrop(providers: providers, isChecked: true)
    }
    
    func handleDropOriginal(providers: [NSItemProvider]) -> Bool {
        return handleDrop(providers: providers, isChecked: false)
    }

    func selectCheckedFolder() {
        selectFolder(isChecked: true)
    }

    func selectOriginalFolder() {
        selectFolder(isChecked: false)
    }

    private func handleDrop(providers: [NSItemProvider], isChecked: Bool) -> Bool {
        guard let provider = providers.first else { return false }

        Task { [weak self] in
            guard let self,
                  let url = await self.itemProviderResolver.resolve(from: provider) else { return }
            await self.setFolder(url: url, isChecked: isChecked)
        }
        return true
    }

    private func selectFolder(isChecked: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = isChecked ? String(localized: "选择待整理文件夹") : String(localized: "选择目标文件夹")

        if panel.runModal() == .OK, let url = panel.url {
            accessCoordinator.register(url: url)
            Task {
                await setFolder(url: url, isChecked: isChecked)
            }
        }
    }
    
    func setFolder(url: URL, isChecked: Bool) async {
        do {
            try EditedImageFileScanning().validateDirectory(url)
        } catch {
            return
        }

        if isChecked {
            self.checkedFolderURL = url
        } else {
            self.originalFolderURL = url
        }
        
        await performScanAndCompare()
    }
    
    func performScanAndCompare() async {
        isScanning = true
        defer { isScanning = false }

        do {
            let result = try await scanAndCompareUseCase.execute(
                checkedFolderURL: checkedFolderURL,
                originalFolderURL: originalFolderURL
            )

            checkedFiles = result.checkedFiles
            originalFiles = result.originalFiles
            diffResults = result.diffResults
            statusCounts = result.statusCounts
            applyFilter()
        } catch {
            checkedFiles = []
            originalFiles = []
            diffResults = []
            filteredResults = []
            statusCounts = [.match: 0, .mismatch: 0]
        }
    }
    
    // MARK: - Organization Logic
    
    func organizeImages() async {
        guard let checkedRoot = checkedFolderURL, let originalRoot = originalFolderURL, !diffResults.isEmpty else { return }

        isScanning = true
        defer {
            isScanning = false
            Task {
                await performScanAndCompare()
            }
        }

        let result = await organizeImagesUseCase.execute(
            diffResults: diffResults,
            checkedRoot: checkedRoot,
            originalRoot: originalRoot
        )
        let report = TaskReport(
            taskKind: "edited-image-organizer",
            startedAt: Date(),
            endedAt: Date(),
            successCount: result.movedCount,
            skippedCount: result.skippedCount,
            failedCount: result.failedCount,
            records: result.records
        )
        _ = try? reportStore.save(report)
        organizeResultMessage = TaskReportPresentation(report: report).message
        showOrganizeResult = true
    }
    
    func applyFilter() {
        if let filter = selectedStatusFilter {
            filteredResults = diffResults.filter { $0.status == filter }
        } else {
            filteredResults = diffResults
        }
    }
    
    func selectFilter(_ status: DiffStatus?) {
        selectedStatusFilter = status
        applyFilter()
    }
    
    func openFile(_ file: ImageFile?) {
        guard let file = file else { return }
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }
    
    func clearAll() {
        checkedFolderURL = nil
        originalFolderURL = nil
        checkedFiles = []
        originalFiles = []
        diffResults = []
        filteredResults = []
        isScanning = false
        selectedStatusFilter = nil
        statusCounts = [.match: 0, .mismatch: 0]
    }
}
