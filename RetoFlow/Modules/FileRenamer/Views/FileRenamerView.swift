import SwiftUI
import UniformTypeIdentifiers

struct FileRenamerView: View {
    @StateObject private var viewModel = FileRenamerViewModel()
    @State private var selectedFileIDs = Set<UUID>()
    @State private var showRuleHelp = false
    
    var body: some View {
        HSplitView {
            // 左侧：文件列表
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .background(Color.clear)

                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "character.cursor.ibeam")
                            .font(.system(size: ToolPanelTypography.dropZoneIconSize))
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("待重命名文件")
                                .font(.system(size: ToolPanelTypography.panelTitleSize, weight: ToolPanelTypography.regularWeight))
                            Text("支持拖放文件或文件夹，文件夹会自动展开并加入列表")
                                .font(.system(size: ToolPanelTypography.compactSupportingTextSize, weight: ToolPanelTypography.regularWeight))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("添加文件", action: viewModel.selectFilesAndFolders)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    Divider()
                        .overlay(Color.gray.opacity(0.2))
                        .padding(.horizontal)

                    FileResultTableView(files: viewModel.files, selectedFileIDs: $selectedFileIDs) { ids in
                            viewModel.removeFiles(with: ids)
                        } dropAction: { providers in
                            viewModel.addFiles(providers)
                        }
                    }
                }
                .padding()
                .frame(minWidth: 300, idealWidth: 600, maxWidth: .infinity)
            
            // 右侧：规则配置
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("重命名规则")
                            .font(.system(size: ToolPanelTypography.panelTitleSize, weight: ToolPanelTypography.regularWeight))
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        Menu {
                            ForEach(RenameRuleType.allCases) { type in
                                Button(type.displayName) {
                                    viewModel.addRule(type)
                                }
                            }
                        } label: {
                            Label("添加规则", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .menuStyle(.borderedButton)
                        .frame(maxWidth: .infinity)
                        
                        Button(action: {
                            Task {
                                await viewModel.applyRenaming()
                            }
                        }) {
                            Label("开始重命名", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.files.isEmpty || viewModel.isProcessing)
                        .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)

                }
                .padding()
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach($viewModel.rules) { $rule in
                            RuleRowView(rule: $rule, onDelete: {
                                viewModel.deleteRule(rule)
                            }) {
                                viewModel.ruleDidChange()
                            }
                            Divider()
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                VStack(spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showRuleHelp.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: showRuleHelp ? "chevron.down" : "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                            Text("规则说明")
                                .font(.system(size: ToolPanelTypography.panelTitleSize, weight: ToolPanelTypography.regularWeight))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color(nsColor: .controlBackgroundColor))

                    if showRuleHelp {
                        Divider()

                        ScrollView {
                            RuleDescriptionContentView()
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 260)
                        .background(Color(nsColor: .windowBackgroundColor))
                    }
                }
            }
            .frame(minWidth: 300, idealWidth: 300, maxWidth: 300)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 600, maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            viewModel.addFiles(providers)
            return true
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: {
                    viewModel.clearFiles()
                }) {
                    Label("清空列表", systemImage: "trash")
                }
                .help("清空文件列表")
                .disabled(viewModel.files.isEmpty)
            }
        }
        .alert("任务摘要", isPresented: $viewModel.showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}

struct RuleDescriptionContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                DescriptionItem(title: "替换文本", content: "查找文件名中的指定文本并替换为新文本。支持简单字符串替换。")
                DescriptionItem(title: "正则表达式", content: "使用正则表达式进行高级匹配和替换。支持捕获组（如 $1, $2）。\n示例：匹配数字 \\d+，替换为 No.$0")
                DescriptionItem(title: "移除文本", content: "支持多种移除模式：\n• 通配符：如 *test* 移除包含test的部分\n• 范围：指定起始位置和长度\n• 特定文本之前/之后的内容")
                DescriptionItem(title: "添加前缀", content: "在文件名最前面添加指定文本。")
                DescriptionItem(title: "添加后缀", content: "在文件名最后面（扩展名之前）添加指定文本。")
            }

            Group {
                DescriptionItem(title: "序列号", content: "为文件添加递增的数字序列。\n可配置起始数字、位数（补零）以及添加位置（开头或结尾）。")
                DescriptionItem(title: "大小写转换", content: "将文件名转换为全部大写、全部小写或首字母大写。")
                DescriptionItem(title: "修改扩展名", content: "修改文件的后缀名（不包含点）。")
            }
        }
    }
}

struct DescriptionItem: View {
    let title: LocalizedStringKey
    let content: LocalizedStringKey
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
            Text(content)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct RuleRowView: View {
    @Binding var rule: RenameRule
    var onDelete: () -> Void
    var onChange: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: $rule.isEnabled)
                    .labelsHidden()
                    .onChange(of: rule.isEnabled) { onChange() }
                
                Text(rule.type.displayName)
                    .fontWeight(.bold)
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            
            Group {
                switch rule.type {
                case .replace:
                    TextField("查找", text: $rule.findText)
                        .onChange(of: rule.findText) { onChange() }
                    TextField("替换为", text: $rule.replaceText)
                        .onChange(of: rule.replaceText) { onChange() }
                    
                case .regex:
                    TextField("正则匹配 (如: \\d+)", text: $rule.regexPattern)
                        .onChange(of: rule.regexPattern) { onChange() }
                    TextField("替换模板 (如: $1)", text: $rule.replaceText)
                        .onChange(of: rule.replaceText) { onChange() }
                    
                case .remove:
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("移除方式", selection: $rule.removeType) {
                            ForEach(RemoveType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: rule.removeType) { onChange() }
                        
                        switch rule.removeType {
                        case .range:
                            HStack {
                                Text("起始位置:")
                                TextField("1", value: $rule.removeStart, formatter: NumberFormatter())
                                    .frame(width: 50)
                                Text("长度:")
                                TextField("1", value: $rule.removeLength, formatter: NumberFormatter())
                                    .frame(width: 50)
                            }
                            .onChange(of: rule.removeStart) { onChange() }
                            .onChange(of: rule.removeLength) { onChange() }
                            
                        case .wildcard:
                            TextField("匹配模式 (如: *test*)", text: $rule.removeText)
                                .onChange(of: rule.removeText) { onChange() }
                                
                        case .after:
                            TextField("在此文本之后 (含)", text: $rule.removeText)
                                .onChange(of: rule.removeText) { onChange() }
                                
                        case .before:
                            TextField("在此文本之前 (含)", text: $rule.removeText)
                                .onChange(of: rule.removeText) { onChange() }
                        case .filename:
                            Text("将移除整个文件名，仅保留扩展名")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }

                case .prefix:
                    TextField("前缀文本", text: $rule.prefixText)
                        .onChange(of: rule.prefixText) { onChange() }
                    
                case .suffix:
                    TextField("后缀文本", text: $rule.suffixText)
                        .onChange(of: rule.suffixText) { onChange() }
                    
                case .sequence:
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("位置:")
                            Picker("", selection: $rule.sequencePosition) {
                                ForEach(SequencePosition.allCases) { pos in
                                    Text(pos.displayName).tag(pos)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .onChange(of: rule.sequencePosition) { onChange() }
                        }
                        
                        HStack {
                            Text("起始:")
                            TextField("1", value: $rule.sequenceStart, formatter: NumberFormatter())
                                .frame(width: 50)
                                .onChange(of: rule.sequenceStart) { onChange() }
                            
                            Text("位数:")
                            TextField("3", value: $rule.sequencePadding, formatter: NumberFormatter())
                                .frame(width: 40)
                                .onChange(of: rule.sequencePadding) { onChange() }
                        }
                    }
                    
                case .caseChange:
                    Picker("转换类型", selection: $rule.caseConversion) {
                        ForEach(CaseConversionType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: rule.caseConversion) { onChange() }

                case .extensionChange:
                    TextField("新扩展名 (不带点)", text: $rule.newExtension)
                        .onChange(of: rule.newExtension) { onChange() }
                }
            }
            .textFieldStyle(.roundedBorder)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct FileResultTableView: View {
    let files: [RenamableFile]
    @Binding var selectedFileIDs: Set<UUID>
    let onDelete: (Set<UUID>) -> Void
    let dropAction: ([NSItemProvider]) -> Void
    
    var body: some View {
        Table(files, selection: $selectedFileIDs) {
            TableColumn("原始文件名") { file in
                HStack {
                    Image(systemName: file.statusIcon)
                        .foregroundColor(file.error != nil ? .red : (file.newFilename != file.originalFilename ? .blue : .secondary))
                    
                    Text(file.originalFilename)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button("从列表中移除") {
                        onDelete([file.id])
                    }
                }
            }
            
            TableColumn("预览新文件名") { file in
                HStack {
                    Text(file.newFilename)
                        .foregroundColor(file.newFilename != file.originalFilename ? .primary : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let error = file.error {
                        Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                }
            }
        }
        .frame(minWidth: 300)
        .onDeleteCommand {
            onDelete(selectedFileIDs)
            selectedFileIDs.removeAll()
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            dropAction(providers)
            return true
        }
    }
}
