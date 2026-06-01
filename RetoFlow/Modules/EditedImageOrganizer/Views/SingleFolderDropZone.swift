import SwiftUI
import UniformTypeIdentifiers

struct SingleFolderDropZone: View {
    let title: LocalizedStringKey
    let buttonTitle: LocalizedStringKey
    let icon: String
    let folderURL: URL?
    let fileCount: Int
    let onDrop: ([NSItemProvider]) -> Bool
    let onSelect: () -> Void
    
    @State private var isTargeted: Bool = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTargeted ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                .background(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(folderURL == nil ? .gray : .accentColor)

                if let name = folderURL?.lastPathComponent {
                    Text(name)
                        .font(.system(size: ToolPanelTypography.panelTitleSize, weight: ToolPanelTypography.boldWeight))
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(title)
                        .font(.system(size: ToolPanelTypography.panelTitleSize, weight: ToolPanelTypography.boldWeight))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if let url = folderURL {
                    Text(url.path)
                        .font(.system(size: ToolPanelTypography.supportingTextSize, weight: ToolPanelTypography.regularWeight))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("拖放文件夹到此处")
                        .font(.system(size: ToolPanelTypography.supportingTextSize, weight: ToolPanelTypography.regularWeight))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

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
