import SwiftUI
import UniformTypeIdentifiers

struct EditedImageOrganizerView: View {
    @StateObject private var viewModel = EditedImageOrganizerViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部拖放区域
            HStack(spacing: 20) {
                SingleFolderDropZone(
                    title: "待整理文件夹",
                    buttonTitle: "选择文件夹",
                    icon: "folder.badge.questionmark",
                    folderURL: viewModel.checkedFolderURL,
                    fileCount: viewModel.checkedFiles.count,
                    onDrop: viewModel.handleDropChecked,
                    onSelect: viewModel.selectCheckedFolder
                )
                
                SingleFolderDropZone(
                    title: "目标文件夹",
                    buttonTitle: "选择文件夹",
                    icon: "folder.fill",
                    folderURL: viewModel.originalFolderURL,
                    fileCount: viewModel.originalFiles.count,
                    onDrop: viewModel.handleDropOriginal,
                    onSelect: viewModel.selectOriginalFolder
                )
            }
            .padding()
            .frame(height: 180)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // 统计与筛选栏
            HStack {
                Text("比对结果: \(viewModel.diffResults.count) 个文件")
                    .font(.system(size: ToolPanelTypography.panelTitleSize, weight: ToolPanelTypography.regularWeight))
                
                Spacer()
                
                Picker("", selection: $viewModel.selectedStatusFilter) {
                    Text("全部 (\(viewModel.diffResults.count))").tag(Optional<DiffStatus>.none)
                    Text("不匹配 (\(viewModel.statusCounts[.mismatch] ?? 0))").tag(Optional<DiffStatus>.some(.mismatch))
                    Text("匹配 (\(viewModel.statusCounts[.match] ?? 0))").tag(Optional<DiffStatus>.some(.match))
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            
            // 结果列表
            if viewModel.isScanning {
                VStack {
                    Spacer()
                    ProgressView("正在扫描与比对...")
                    Spacer()
                }
            } else {
                Table(viewModel.filteredResults) {
                    TableColumn("待整理文件夹") { result in
                        FileCell(file: result.checkedFile, color: result.status == .match ? .green : .red)
                            .contentShape(Rectangle())
                            .contextMenu {
                                if let file = result.checkedFile {
                                    Button {
                                        NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                    } label: {
                                        Label("在访达中显示", systemImage: "folder")
                                    }
                                    Button {
                                        let pasteboard = NSPasteboard.general
                                        pasteboard.clearContents()
                                        pasteboard.setString(file.filename, forType: .string)
                                    } label: {
                                        Label("复制文件名", systemImage: "doc.on.doc")
                                    }
                                }
                            }
                    }
                    
                    TableColumn("状态") { result in
                        VStack {
                            Image(systemName: result.status == .match ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.status == .match ? .green : .red)
                                .font(.title2)
                            Text(result.status == .match ? "匹配" : "不匹配")
                                .font(.caption2)
                                .foregroundColor(result.status == .match ? .green : .red)
                        }
                    }
                    .width(80)
                    .alignment(TableColumnAlignment.center)
                    
                    TableColumn("目标文件夹") { result in
                        FileCell(file: result.originalFile, color: result.status == .match ? .green : .red, alignRight: true)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .contentShape(Rectangle())
                            .contextMenu {
                                if let file = result.originalFile {
                                    Button {
                                        NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                    } label: {
                                        Label("在访达中显示", systemImage: "folder")
                                    }
                                    Button {
                                        let pasteboard = NSPasteboard.general
                                        pasteboard.clearContents()
                                        pasteboard.setString(file.filename, forType: .string)
                                    } label: {
                                        Label("复制文件名", systemImage: "doc.on.doc")
                                    }
                                }
                            }
                    }
                    .alignment(TableColumnAlignment.trailing)
                }
                
                // 底部操作栏
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            viewModel.showOrganizeConfirmation = true
                        }) {
                            Label("开始整理", systemImage: "folder.badge.gearshape")
                        }
                        .disabled(viewModel.diffResults.isEmpty || viewModel.isScanning)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Spacer()
                        
                        Text("共 \(viewModel.diffResults.count) 个比对结果")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    Task {
                        await viewModel.performScanAndCompare()
                    }
                }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .help("刷新比对结果")
                .disabled(viewModel.isScanning || (viewModel.checkedFolderURL == nil && viewModel.originalFolderURL == nil))
                
                Button(action: {
                    viewModel.clearAll()
                }) {
                    Label("清空", systemImage: "trash")
                }
                .help("清空所有列表")
            }
        }
        .alert("确认整理", isPresented: $viewModel.showOrganizeConfirmation) {
            Button("取消", role: .cancel) { }
            Button("确认整理", role: .destructive) {
                Task {
                    await viewModel.organizeImages()
                }
            }
        } message: {
            Text(SafeOperationReleaseCopy.organizerConfirmationMessage)
        }
        .alert("任务摘要", isPresented: $viewModel.showOrganizeResult) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.organizeResultMessage)
        }
    }
}
