import SwiftUI

struct AboutView: View {
    private let fallbackVersion = "1.0.0"
    private let fallbackBuild = "100"
    private let repositoryURL = URL(string: "https://github.com/elisontz/RetoFlow")!

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
                    Link(destination: repositoryURL) {
                        HStack(spacing: 6) {
                            GitHubMark()
                                .frame(width: 16, height: 16)
                            Text("GitHub")
                                .font(.system(size: ToolPanelTypography.compactSupportingTextSize, weight: ToolPanelTypography.regularWeight))
                        }
                        .foregroundStyle(.primary)
                        .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                    .help("打开 RetoFlow 的 GitHub 仓库")
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

private struct GitHubMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.primary)

            Circle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(width: 8, height: 6)
                .offset(y: 4)

            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(.primary)
                    .frame(width: 3, height: 6)
                    .rotationEffect(.degrees(28))
                RoundedRectangle(cornerRadius: 1)
                    .fill(.primary)
                    .frame(width: 3, height: 6)
                    .rotationEffect(.degrees(-28))
            }
            .offset(y: 7)
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(.primary)
                .frame(width: 5, height: 5)
                .rotationEffect(.degrees(45))
                .offset(x: 3, y: 1)
        }
        .overlay(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(.primary)
                .frame(width: 5, height: 5)
                .rotationEffect(.degrees(45))
                .offset(x: -3, y: 1)
        }
        .accessibilityHidden(true)
    }
}
