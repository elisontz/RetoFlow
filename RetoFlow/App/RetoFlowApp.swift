import SwiftUI

@main
struct RetoFlowApp: App {
    @StateObject private var navigationState = AppNavigationState()
    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.system.rawValue

    @MainActor
    init() {
        // Ensure the app runs as a regular app (shows in Dock)
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(navigationState)
                .onAppear {
                    applyAppearanceMode()
                    NSApplication.shared.activate()
                }
                .onChange(of: appearanceModeRawValue) {
                    applyAppearanceMode()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .help) {
                Button("RetoFlow 帮助") {
                    navigationState.navigate(to: .help)
                }
            }
        }
    }

    private func applyAppearanceMode() {
        let mode = AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
        switch mode {
        case .system:
            NSApplication.shared.appearance = nil
        case .light:
            NSApplication.shared.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
