import SwiftUI

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.system.rawValue
    @AppStorage("exportConcurrencyMode") private var exportConcurrencyModeRawValue: String = ExportConcurrencyMode.auto.rawValue
#if DEBUG
    @AppStorage("enableExporterDebugLogs") private var enableExporterDebugLogs: Bool = false
#endif

    private var selectedAppearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    private var selectedConcurrencyMode: ExportConcurrencyMode {
        ExportConcurrencyMode(rawValue: exportConcurrencyModeRawValue) ?? .auto
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("设置")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 16) {
                    Text("外观")
                        .font(.title2)

                    HStack(spacing: 14) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Button {
                                appearanceModeRawValue = mode.rawValue
                            } label: {
                                AppearanceOptionCard(
                                    mode: mode,
                                    isSelected: selectedAppearance == mode
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 12) {
                    Text("图片导出压缩设置")
                        .font(.title2)

                    HStack(spacing: 10) {
                        Text("导出并发")
                            .font(.body)
                        Picker("", selection: $exportConcurrencyModeRawValue) {
                            ForEach(ExportConcurrencyMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    Text(selectedConcurrencyMode == .auto ? "自动模式会根据芯片型号选择默认并发，并结合内存与导出配置修正。" : "如果你开启了文件大小限制，并发设为 8 往往速度更好；设为 10 可能会变慢。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

#if DEBUG
                VStack(alignment: .leading, spacing: 12) {
                    Text("开发者")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Toggle("显示图片导出调试日志", isOn: $enableExporterDebugLogs)
                        .toggleStyle(.switch)

                    Text("仅 Debug 构建可见，用于查看并发策略和导出耗时。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
#endif

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct AppearanceOptionCard: View {
    let mode: AppearanceMode
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(mode.gradient)
                    .frame(width: 136, height: 80)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.75))
                    .frame(width: 52, height: 12)
                    .padding(.leading, 10)
                    .padding(.top, 10)

                HStack(spacing: 8) {
                    Circle().fill(Color.red.opacity(0.85)).frame(width: 7, height: 7)
                    Circle().fill(Color.yellow.opacity(0.85)).frame(width: 7, height: 7)
                    Circle().fill(Color.green.opacity(0.85)).frame(width: 7, height: 7)
                }
                .padding(.leading, 64)
                .padding(.top, 58)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 3 : 1)
            )

            Text(mode.title)
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
}
