import SwiftUI
import AppCore

@main
struct BiokineticsDosimetryApp: SwiftUI.App {
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView(coordinator: coordinator)
        }
    }
}
