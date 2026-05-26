import AppCore
import SwiftUI

@main
struct BiokineticsDosimetryApp: SwiftUI.App {
    let coordinator: NavigationCoordinator

    init() {
        coordinator = NavigationCoordinator(store: .app(environment: .live))
    }

    var body: some Scene {
        WindowGroup {
            coordinator.rootView
        }
    }
}
