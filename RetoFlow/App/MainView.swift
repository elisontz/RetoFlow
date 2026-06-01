import SwiftUI

struct MainView: View {
    @EnvironmentObject private var navigationState: AppNavigationState
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $navigationState.selectedModule) {
                    Section {
                        ForEach(AppModule.navigationCases) { module in
                            NavigationLink(value: module) {
                                Label(module.displayName, systemImage: module.icon)
                            }
                        }
                    }
                }
                .navigationTitle("Photo Assistant")
                .listStyle(.sidebar)

                Spacer(minLength: 0)

                VStack(spacing: 4) {
                    footerButton(for: .help)
                    footerButton(for: .settings)
                    footerButton(for: .about)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        } detail: {
            if let module = navigationState.selectedModule {
                switch module {
                case .rawFinder:
                    RawFinderView()
                case .organizer:
                    EditedImageOrganizerView()
                case .renamer:
                    FileRenamerView()
                case .exporter:
                    ImageExporterView()
                case .settings:
                    SettingsView()
                case .about:
                    AboutView()
                case .help:
                    HelpView()
                }
            } else {
                Text("请从侧边栏选择一个功能")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
    }

    @ViewBuilder
    private func footerButton(for module: AppModule) -> some View {
        Button {
            navigationState.navigate(to: module)
        } label: {
            Label(module.displayName, systemImage: module.icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(navigationState.selectedModule == module ? Color.white : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(navigationState.selectedModule == module ? Color.accentColor : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
