import AppCore
import SwiftUI

@main
struct BiokineticsDosimetryApp: SwiftUI.App {
    /// The coordinator owns the store and all feature ViewModels.
    /// `@State` keeps the single instance stable across re-renders.
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            coordinator.rootView
        }
    }
}
