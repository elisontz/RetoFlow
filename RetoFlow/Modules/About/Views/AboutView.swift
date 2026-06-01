import SwiftUI

struct AboutView: View {
    private let fallbackVersion = "1.0.0"
    private let fallbackBuild = "100"

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? fallbackVersion
        return String(localized: "版本: \(version)")
    }

    private var buildText: String {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? fallbackBuild
        return String(localized: "构建: \(build)")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("关于 RetoFlow")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("面向摄影后期工作流的 macOS 辅助工具，聚焦批量处理、文件整理与导出压缩。")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("版本信息：")
                        .font(.title2)
                    Text("RetoFlow")
                        .font(.system(size: ToolPanelTypography.compactSupportingTextSize, weight: ToolPanelTypography.regularWeight))
                    Text("开发者: elisontz")
                        .font(.system(size: ToolPanelTypography.compactSupportingTextSize, weight: ToolPanelTypography.regularWeight))
                    Text("版权: © 2026 elisontz. All rights reserved.")
                        .font(.system(size: ToolPanelTypography.compactSupportingTextSize, weight: ToolPanelTypography.regularWeight))
                        .foregroundColor(.primary)
                    Text(versionText)
                        .font(.system(size: ToolPanelTypography.compactSupportingTextSize, weight: ToolPanelTypography.regularWeight))
                        .foregroundColor(.primary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
