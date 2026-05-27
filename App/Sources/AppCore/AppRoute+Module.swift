import AppDomain
import CalculatorFeature
import EditorFeature
import FP
import HomeFeature
import NavigationFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftUI

// MARK: - AppRoute → View

public extension AppRoute {
    @MainActor
    static func scene(store: MainStoreType) -> some Scene {
        WindowGroup {
            root(store: store, entry: .home)
        }
    }

    @MainActor
    private static func root(store: MainStoreType, entry: AppRoute) -> some View {
        AppRootView(viewModel: NavigationFeature.ViewModel.from(store: store)) {
            entry.view(in: store)
                .navigationDestination(for: AppRoute.self, destination: flip(AppRoute.view)(store))
        }
    }

    /// Produces the view for this route, already lifted to `AppAction / AppState / World`.
    /// `@ViewBuilder` unifies the concrete per-route view types without `AnyView` erasure.
    @MainActor @ViewBuilder
    func view(in store: MainStoreType) -> some View {
        switch self {
        case .home:       Module.home.lift().view(for: store)
        case .editor:     Module.editor.lift().view(for: store)
        case .calculator: Module.calculator.lift().view(for: store)
        }
    }
}
