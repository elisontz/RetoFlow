import SwiftUI
import UniformTypeIdentifiers

struct ImageExporterView: View {
    @StateObject private var viewModel = ImageExporterViewModel()
#if DEBUG
    @AppStorage("enableExporterDebugLogs") private var enableExporterDebugLogs = false
#endif
    
    var body: some View {
        let minLeftWidth: CGFloat = 300
        let minRightWidth: CGFloat = 300

        return HSplitView {
            // 左侧：拖放区域 + 文件列表 (2/3)
            VStack(spacing: 0) {
                // 顶部拖放区域
                ImageDropZone(
                    title: "图片文件夹",
                    buttonTitle: "添加图片",
                    icon: "photo.on.rectangle.angled",
                    folders: viewModel.folders,
                    directFileCount: viewModel.directFiles.count,
                    fileCount: viewModel.images.count,
                    onDrop: { providers in
                        viewModel.addImages(providers)
                        return true
                    },
                    onRemove: { index in
                        viewModel.removeFolder(at: index)
                    },
                    onClearDirectFiles: {
                        viewModel.clearDirectFiles()
                    },
                    onSelect: viewModel.selectInputSources
                )
                .padding()
                .frame(height: 200)
                .background(Color(nsColor: .controlBackgroundColor))
                
                Divider()
                
                // 工具栏
                HStack {
                    Text("图片列表: \(viewModel.images.count) 个文件")
                        .font(.system(size: ToolPanelTypography.panelTitleSize, weight: ToolPanelTypography.regularWeight))
                    
                    Spacer()
                    
                    // 状态筛选器
                    if !viewModel.images.isEmpty {
                        Picker("", selection: $viewModel.selectedStatusFilter) {
                            Text("全部 (\(viewModel.images.count))").tag(Optional<ExportableImage.ExportStatus>.none)
                            Text("等待 (\(viewModel.statusCounts[.pending] ?? 0))").tag(Optional<ExportableImage.ExportStatus>.some(.pending))
                            Text("成功 (\(viewModel.statusCounts[.success] ?? 0))").tag(Optional<ExportableImage.ExportStatus>.some(.success))
                            Text("失败 (\(viewModel.statusCounts[.failed] ?? 0))").tag(Optional<ExportableImage.ExportStatus>.some(.failed))
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 350)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(nsColor: .windowBackgroundColor))
                
                Divider()
                
                // 文件列表
                Table(viewModel.filteredImages) {
                        TableColumn("文件名") { image in
                            HStack {
                                Image(systemName: "photo")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(image.fileName)
                                        .font(.body)
                                    Text(image.folderPath)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([image.url])
                                } label: {
                                    Label("在访达中显示", systemImage: "folder")
                                }
                                
                                if !viewModel.isExporting {
                                    Button(role: .destructive) {
                                        viewModel.removeImage(image)
                                    } label: {
                                        Label("从列表移除", systemImage: "trash")
                                    }
                                }
                            }
                            .onTapGesture(count: 2) {
                                NSWorkspace.shared.activateFileViewerSelecting([image.url])
                            }
                        }
                        
                        TableColumn("状态") { image in
                            VStack(spacing: 4) {
                                Image(systemName: image.status.icon)
                                    .foregroundColor(image.status.color)
                                    .font(.title3)
                                
                                if image.status == .exporting {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text(statusText(for: image.status))
                                        .font(.caption2)
                                        .foregroundColor(image.status.color)
                                }
                            }
                        }
                        .width(70)
                        .alignment(TableColumnAlignment.center)
                        
                        TableColumn("导出信息") { image in
                            VStack(alignment: .center, spacing: 2) {
                                if image.status == .success {
                                    if let size = image.formattedFileSize {
                                        Text(size)
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                    if let quality = image.formattedQuality {
                                        Text("质量: \(quality)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else if image.status == .failed, let error = image.error {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .lineLimit(2)
                                } else {
                                    Text("-")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .width(min: 100, ideal: 120, max: 150)
                        .alignment(TableColumnAlignment.center)
                    }
                }
                .frame(minWidth: minLeftWidth, idealWidth: 400, maxWidth: .infinity)
            
            // 右侧：配置面板 + 导出按钮 (1/3)
            VStack(spacing: 0) {
                GeometryReader { rightProxy in
                    let horizontalInset: CGFloat = 12
                    let availableWidth = max(0, rightProxy.size.width - horizontalInset * 2)
                    let contentWidth = min(availableWidth, 520)

                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("导出JPG设置")
                                    .font(.system(size: ToolPanelTypography.panelTitleSize, weight: ToolPanelTypography.regularWeight))

                                
                                // 尺寸限制
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("尺寸限制")
                                        .font(.system(size: ToolPanelTypography.panelTitleSize, weight: ToolPanelTypography.regularWeight))
                                    DimensionControls(viewModel: viewModel)
                                        .padding(12)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .cornerRadius(8)
                                }
                                
                                // 文件大小
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("文件大小")
                                        .font(.system(size: ToolPanelTypography.panelTitleSize, weight: ToolPanelTypography.regularWeight))
                                    FileSizeControls(viewModel: viewModel)
                                        .padding(12)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .cornerRadius(8)
                                }
                                
                                // 输出设置
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("输出设置")
                                        .font(.system(size: ToolPanelTypography.panelTitleSize, weight: ToolPanelTypography.regularWeight))
                                    OutputControls(viewModel: viewModel)
                                        .padding(12)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .cornerRadius(8)
                                }
                            }
                            .padding()
                            .frame(width: contentWidth, height: nil, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipped()
                        
                        Divider()
                        
                        // 底部导出按钮
                        VStack(spacing: 12) {
                            if viewModel.isExporting {
                                VStack(spacing: 8) {
                                    ProgressView(value: viewModel.progress) {
                                        HStack {
                                            Text("导出中")
                                                .font(.system(size: ToolPanelTypography.panelTitleSize, weight: ToolPanelTypography.regularWeight))
                                            Spacer()
                                            Text(viewModel.progress.formatted(.percent.precision(.fractionLength(0))))
                                                .font(.system(size: ToolPanelTypography.panelTitleSize, weight: ToolPanelTypography.regularWeight))
                                        }
                                    }
                                    
                                    Text("正在处理: \(viewModel.currentFileName)")
                                        .font(.system(size: ToolPanelTypography.supportingTextSize, weight: ToolPanelTypography.regularWeight))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            } else {
                                Button(action: {
                                    viewModel.startExport()
                                }) {
                                    Label("开始导出", systemImage: "arrow.down.doc")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .disabled(viewModel.images.isEmpty)
                            }

#if DEBUG
                            if enableExporterDebugLogs && !viewModel.debugLogs.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("调试日志")
                                            .font(.system(size: ToolPanelTypography.supportingTextSize, weight: ToolPanelTypography.regularWeight))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Button("复制") {
                                            viewModel.copyDebugLogsToClipboard()
                                        }
                                        .buttonStyle(.borderless)
                                        .font(.caption)
                                    }

                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(Array(viewModel.debugLogs.suffix(12).enumerated()), id: \.offset) { _, line in
                                                Text(line)
                                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                                    .foregroundColor(.secondary)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                    }
                                    .frame(height: 110)
                                    .padding(8)
                                    .background(Color(nsColor: .windowBackgroundColor))
                                    .cornerRadius(8)
                                }
                            }
#endif
                        }
                        .padding()
                        .frame(width: contentWidth, height: nil)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(Color(nsColor: .controlBackgroundColor))
                    }
                }
            }
            .frame(minWidth: minRightWidth, idealWidth: 300, maxWidth: 300, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    viewModel.clearAll()
                }) {
                    Label("清空", systemImage: "trash")
                }
                .help("清空所有列表")
                .disabled(viewModel.isExporting)
            }
        }
        .alert("提示", isPresented: $viewModel.showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
    
    private func statusText(for status: ExportableImage.ExportStatus) -> String {
        switch status {
        case .pending: return String(localized: "等待")
        case .exporting: return String(localized: "导出中")
        case .success: return String(localized: "成功")
        case .failed: return String(localized: "失败")
        }
    }
}

// MARK: - Image Drop Zone

struct ImageDropZone: View {
    let title: LocalizedStringKey
    let buttonTitle: LocalizedStringKey
    let subtitle: LocalizedStringKey? = nil
    let icon: String
    let folders: [URL]
    let directFileCount: Int
    let fileCount: Int
    let onDrop: ([NSItemProvider]) -> Bool
    let onRemove: (Int) -> Void
    let onClearDirectFiles: () -> Void
    let onSelect: () -> Void
    
    @State private var isTargeted: Bool = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTargeted ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                .background(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: ToolPanelTypography.dropZoneIconSize))
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: ToolPanelTypography.panelTitleSize, weight: ToolPanelTypography.boldWeight))
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: ToolPanelTypography.compactSupportingTextSize, weight: ToolPanelTypography.regularWeight))
                                .foregroundColor(.secondary)
                        } else {
                            Text("支持 JPG、PNG、TIF、PSD")
                                .font(.system(size: ToolPanelTypography.compactSupportingTextSize, weight: ToolPanelTypography.regularWeight))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)

                Divider()
                    .overlay(Color.gray.opacity(0.2))
                    .padding(.horizontal)
                
                List {
                    if folders.isEmpty && directFileCount == 0 {
                        HStack {
                            Image(systemName: icon)
                                .foregroundColor(.secondary)
                            Text("拖放文件夹或文件到此处")
                                .font(.system(size: ToolPanelTypography.supportingTextSize, weight: ToolPanelTypography.regularWeight))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }

                    ForEach(0..<folders.count, id: \.self) { index in
                        let url = folders[index]
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.secondary)
                            Text(url.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .font(.system(size: ToolPanelTypography.supportingTextSize, weight: ToolPanelTypography.regularWeight))
                            Spacer()
                            Button(action: {
                                onRemove(index)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                    
                    if directFileCount > 0 {
                        HStack {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.secondary)
                            Text("直接添加的文件: \(directFileCount) 个")
                                .lineLimit(1)
                                .font(.system(size: ToolPanelTypography.supportingTextSize, weight: ToolPanelTypography.regularWeight))
                            Spacer()
                            
                            Button(action: onClearDirectFiles) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(buttonTitle, action: onSelect)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                Spacer()
            }
            .padding(.top, 12)
            .padding(.horizontal, 12)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            onDrop(providers)
        }
    }
}

// MARK: - Dimension Controls

struct DimensionControls: View {
    @ObservedObject var viewModel: ImageExporterViewModel
    @State private var activeLimit: ExportConfiguration.DimensionLimitKind? = .shortEdge
    @State private var maxWidthText = "2500"
    @State private var maxHeightText = "2500"
    @State private var maxLongEdgeText = "2500"
    @State private var maxShortEdgeText = "2500"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: binding(for: .width)) {
                HStack {
                    Text("宽度")
                        .frame(minWidth: 60, alignment: .leading)
                    TextField("", text: $maxWidthText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 80)
                        .disabled(activeLimit != .width)
                    Text("px").foregroundColor(.secondary).font(.system(size: ToolPanelTypography.supportingTextSize, weight: ToolPanelTypography.regularWeight))
                }
            }
            
            Toggle(isOn: binding(for: .height)) {
                HStack {
                    Text("高度")
                        .frame(minWidth: 60, alignment: .leading)
                    TextField("", text: $maxHeightText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 80)
                        .disabled(activeLimit != .height)
                    Text("px").foregroundColor(.secondary).font(.system(size: ToolPanelTypography.supportingTextSize, weight: ToolPanelTypography.regularWeight))
                }
            }
            
            Toggle(isOn: binding(for: .longEdge)) {
                HStack {
                    Text("长边")
                        .frame(minWidth: 60, alignment: .leading)
                    TextField("", text: $maxLongEdgeText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 80)
                        .disabled(activeLimit != .longEdge)
                    Text("px").foregroundColor(.secondary).font(.system(size: ToolPanelTypography.supportingTextSize, weight: ToolPanelTypography.regularWeight))
                }
            }
            
            Toggle(isOn: binding(for: .shortEdge)) {
                HStack {
                    Text("短边")
                        .frame(minWidth: 60, alignment: .leading)
                    TextField("", text: $maxShortEdgeText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 80)
                        .disabled(activeLimit != .shortEdge)
                    Text("px").foregroundColor(.secondary).font(.system(size: ToolPanelTypography.supportingTextSize, weight: ToolPanelTypography.regularWeight))
                }
            }
        }
        .onChange(of: activeLimit) { updateConfiguration() }
        .onChange(of: maxWidthText) { updateConfiguration() }
        .onChange(of: maxHeightText) { updateConfiguration() }
        .onChange(of: maxLongEdgeText) { updateConfiguration() }
        .onChange(of: maxShortEdgeText) { updateConfiguration() }
        .onAppear {
            loadConfiguration()
        }
    }

    private func binding(for kind: ExportConfiguration.DimensionLimitKind) -> Binding<Bool> {
        Binding(
            get: { activeLimit == kind },
            set: { isEnabled in
                activeLimit = isEnabled ? kind : nil
            }
        )
    }

    private func loadConfiguration() {
        activeLimit = viewModel.configuration.activeDimensionLimitKind
        maxWidthText = String(viewModel.configuration.maxWidth ?? 2500)
        maxHeightText = String(viewModel.configuration.maxHeight ?? 2500)
        maxLongEdgeText = String(viewModel.configuration.maxLongEdge ?? 2500)
        maxShortEdgeText = String(viewModel.configuration.maxShortEdge ?? 2500)
    }

    private func updateConfiguration() {
        let selectedValue: Int? = switch activeLimit {
        case .width:
            Int(maxWidthText)
        case .height:
            Int(maxHeightText)
        case .longEdge:
            Int(maxLongEdgeText)
        case .shortEdge:
            Int(maxShortEdgeText)
        case nil:
            nil
        }
        viewModel.configuration.selectDimensionLimit(activeLimit, value: selectedValue)
    }
}

// MARK: - File Size Controls

struct FileSizeControls: View {
    @ObservedObject var viewModel: ImageExporterViewModel
    @State private var fileSizeLimitEnabled = true
    @State private var fileSizeText = "5"
    @State private var fileSizeUnit = "MB"
    
    var body: some View {
        Toggle(isOn: $fileSizeLimitEnabled) {
            HStack {
                Text("大小限制")
                    .frame(minWidth: 60, alignment: .leading)
                TextField("", text: $fileSizeText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 60)
                    .disabled(!fileSizeLimitEnabled)
                Picker("", selection: $fileSizeUnit) {
                    Text("KB").tag("KB")
                    Text("MB").tag("MB")
                }
                .frame(maxWidth: 70)
                .disabled(!fileSizeLimitEnabled)
            }
        }
        .onAppear {
            loadConfiguration()
        }
        .onChange(of: fileSizeLimitEnabled) { updateConfiguration() }
        .onChange(of: fileSizeText) { updateConfiguration() }
        .onChange(of: fileSizeUnit) { updateConfiguration() }
    }

    private func loadConfiguration() {
        if let maxFileSizeBytes = viewModel.configuration.maxFileSizeBytes {
            if maxFileSizeBytes % (1024 * 1024) == 0 {
                fileSizeUnit = "MB"
                fileSizeText = String(maxFileSizeBytes / (1024 * 1024))
            } else {
                fileSizeUnit = "KB"
                fileSizeText = String(maxFileSizeBytes / 1024)
            }
            fileSizeLimitEnabled = true
        } else {
            fileSizeLimitEnabled = false
            fileSizeUnit = "MB"
            fileSizeText = "5"
        }
    }

    private func updateConfiguration() {
        if fileSizeLimitEnabled, let size = Double(fileSizeText) {
            let multiplier = fileSizeUnit == "MB" ? 1024 * 1024 : 1024
            viewModel.configuration.maxFileSizeBytes = Int(size * Double(multiplier))
        } else {
            viewModel.configuration.maxFileSizeBytes = nil
        }
    }
}

// MARK: - Output Controls

struct OutputControls: View {
    @ObservedObject var viewModel: ImageExporterViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("保留元数据", isOn: $viewModel.configuration.preserveMetadata)
            Toggle("在原文件夹下创建子文件夹", isOn: $viewModel.configuration.createSubfolder)
            
            if viewModel.configuration.createSubfolder {
                HStack {
                    Text("子文件夹名称后缀")
                        .foregroundColor(.secondary)
                        .font(.system(size: ToolPanelTypography.supportingTextSize, weight: ToolPanelTypography.regularWeight))
                    TextField("", text: $viewModel.configuration.subfolderSuffix)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 100)
                }
                .padding(.leading, 20)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("输出目录:")
                            .foregroundColor(.secondary)
                            .font(.system(size: ToolPanelTypography.supportingTextSize, weight: ToolPanelTypography.regularWeight))
                        Spacer()
                        Button("选择...") {
                            viewModel.selectOutputDirectory()
                        }
                        .controlSize(.small)
                    }
                    
                    Text(viewModel.configuration.hasExplicitOutputTarget ? viewModel.configuration.outputDirectory.path : "尚未选择输出目录")
                        .font(.system(size: ToolPanelTypography.supportingTextSize, weight: ToolPanelTypography.regularWeight))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                }
            }
        }
    }
}
