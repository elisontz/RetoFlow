import SwiftUI
import Combine

@MainActor
class AppNavigationState: ObservableObject {
    @Published var selectedModule: AppModule? = .rawFinder
    
    func navigate(to module: AppModule) {
        selectedModule = module
    }
}
