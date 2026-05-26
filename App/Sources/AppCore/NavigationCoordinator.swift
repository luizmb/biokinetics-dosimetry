import AppDomain
import NavigationFeature
import SwiftRex
import SwiftUI

// MARK: - NavigationCoordinator

/// Reader-style value that captures the app store once and resolves
/// route → view on demand.
///
/// Lifecycle: created alongside the store at the app entry point.
@MainActor
public struct NavigationCoordinator {

    // MARK: - Properties

    private let store: Store<AppAction, AppState, World>

    // MARK: - Init

    public init(store: Store<AppAction, AppState, World>) {
        self.store = store
    }

    // MARK: - Root view

    /// Builds the root `AppRootView`, wiring the `NavigationFeature.ViewModel`.
    public var rootView: some View {
        AppRootView(
            viewModel: NavigationFeature.ViewModel(
                store: store.projection(
                    action: AppAction.prism.navigation.review,
                    state:  AppState.lens.navigation.get
                )
            )
        ) {
            AppRoute.home.view(in: store)
                .navigationDestination(for: AppRoute.self) { route in
                    route.view(in: store)
                }
        }
    }
}
