import SwiftUI
import UniformTypeIdentifiers
import Foundation

struct RawFinderView: View {
    @StateObject private var viewModel = RawFinderViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Drop Area
            HStack(spacing: 20) {
                RawFinderTopDropZone(
                    title: "小图/精选图",
                    buttonTitle: "添加图片",
                    subtitle: "支持 JPG、PNG 等常见图片格式",
                    icon: "photo.on.rectangle",
                    folders: viewModel.imageFolders,
                    directFileCount: viewModel.directImageFiles.count,
                    fileCount: viewModel.imageFiles.count,
                    onDrop: { providers in
                        viewModel.addImageFolders(providers)
                        return true
                    },
                    onRemove: { index in
                        viewModel.removeImageFolder(at: index)
                    },
                    onClearDirectFiles: {
                        viewModel.clearDirectImageFiles()
                    },
                    onSelect: viewModel.selectImageSources
                )
                
                RawFinderTopDropZone(
                    title: "RAW文件库",
                    buttonTitle: "添加文件夹",
                    subtitle: "支持常见相机拍摄的 RAW 格式文件",
                    icon: "camera.fill",
                    folders: viewModel.rawFolders,
                    directFileCount: 0,
                    fileCount: viewModel.rawFiles.count,
                    onDrop: { providers in
                        viewModel.addRawFolders(providers)
                        return true
                    },
                    onRemove: { index in
                        viewModel.removeRawFolder(at: index)
                    },
                    onSelect: viewModel.selectRawFolders
                )
            }
            .padding()
            .frame(height: 180)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Toolbar
            HStack {
                Text("匹配结果: \(viewModel.matches.count) 个文件")
                    .font(.system(size: ToolPanelTypography.panelTitleSize, weight: ToolPanelTypography.regularWeight))
                
                if viewModel.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 8)
                }
                
                Spacer()
                
                Picker("", selection: $viewModel.selectedStatusFilter) {
                    Text("全部 (\(viewModel.matches.count))").tag(Optional<MatchStatus>.none)
                    Text("不匹配 (\(viewModel.statusCounts[.missing] ?? 0))").tag(Optional<MatchStatus>.some(.missing))
                    Text("匹配 (\(viewModel.statusCounts[.matched] ?? 0))").tag(Optional<MatchStatus>.some(.matched))
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            
            // Results List
            if viewModel.isProcessing {
                VStack {
                    Spacer()
                    ProgressView("正在匹配...")
                    Spacer()
                }
            } else {
                Table(viewModel.filteredMatches) {
                    TableColumn("小图/精选图") { match in
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(match.status == .matched ? .green : .red)
                            VStack(alignment: .leading) {
                                Text(match.imageName)
                                    .font(.body)
                                Text(match.imageURL.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([match.imageURL])
                            } label: {
                                Label("在访达中显示", systemImage: "folder")
                            }
                            
                            Button {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(match.imageName, forType: .string)
                            } label: {
                                Label("复制文件名", systemImage: "doc.on.doc")
                            }
                        }
                        .onTapGesture(count: 2) {
                            NSWorkspace.shared.activateFileViewerSelecting([match.imageURL])
                        }
                    }
                    
                    TableColumn("状态") { match in
                        VStack {
                            Image(systemName: match.status.iconName)
                                .foregroundColor(match.status == .matched ? .green : .red)
                                .font(.title2)
                            Text(match.status == .matched ? "匹配" : "未找到")
                                .font(.caption2)
                                .foregroundColor(match.status == .matched ? .green : .red)
                        }
                    }
                    .width(80)
                    .alignment(TableColumnAlignment.center)
                    
                    TableColumn("RAW文件") { match in
                        if let rawURL = match.rawURL {
                            HStack {
                                VStack(alignment: .trailing) {
                                    Text(match.rawName)
                                        .font(.body)
                                    Text(rawURL.path)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Image(systemName: "camera.fill")
                                    .foregroundColor(match.status == .matched ? .green : .red)
                            }
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([rawURL])
                                } label: {
                                    Label("在访达中显示", systemImage: "folder")
                                }
                                
                                Button {
                                    let pasteboard = NSPasteboard.general
                                    pasteboard.clearContents()
                                    pasteboard.setString(match.rawName, forType: .string)
                                } label: {
                                    Label("复制文件名", systemImage: "doc.on.doc")
                                }
                            }
                            .onTapGesture(count: 2) {
                                NSWorkspace.shared.activateFileViewerSelecting([rawURL])
                            }
                        } else {
                            Text("-")
                                .foregroundColor(.secondary.opacity(0.3))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .alignment(TableColumnAlignment.trailing)
                }
                
                // 底部操作栏
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                viewModel.showReplaceConfirmation = true
                            }) {
                                Label("RAW替换小图", systemImage: "doc.on.doc")
                            }
                            .disabled(viewModel.matches.filter { $0.rawURL != nil }.isEmpty || viewModel.isProcessing)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            
                            Button(action: {
                                viewModel.copyMissingRawFilenames()
                            }) {
                                Label("复制缺失RAW列表", systemImage: "list.clipboard")
                            }
                            .disabled(viewModel.matches.filter { $0.status == .missing }.isEmpty)
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                        
                        Spacer()
                        
                        Text("共 \(viewModel.matches.count) 个结果")
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
                        viewModel.updateMatches()
                    }
                }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .help("刷新匹配结果")
                
                Button(action: {
                    viewModel.clearAll()
                }) {
                    Label("清空", systemImage: "trash")
                }
                .help("清空所有列表")
            }
        }
        .alert("确认替换", isPresented: $viewModel.showReplaceConfirmation) {
            Button("取消", role: .cancel) { }
            Button("确认替换", role: .destructive) {
                Task {
                    await viewModel.replaceMatchedImagesWithRaw()
                }
            }
        } message: {
            Text(SafeOperationReleaseCopy.rawFinderConfirmationMessage)
        }
        .alert("任务摘要", isPresented: $viewModel.showReplaceResult) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.replaceResultMessage)
        }
    }
}
