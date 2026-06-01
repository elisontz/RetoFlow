import SwiftUI
import UniformTypeIdentifiers

struct RawFinderTopDropZone: View {
    let title: LocalizedStringKey
    let buttonTitle: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let icon: String
    let folders: [URL]
    let directFileCount: Int
    let fileCount: Int
    let onDrop: ([NSItemProvider]) -> Bool
    let onRemove: (Int) -> Void
    var onClearDirectFiles: (() -> Void)? = nil
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
                            
                            if let onClear = onClearDirectFiles {
                                Button(action: onClear) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
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
