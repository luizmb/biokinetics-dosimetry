import AppDomain
import NavigationFeature
import SwiftRex
import SwiftUI

// MARK: - NavigationCoordinator

/// Reader-style value that captures the app store once and resolves
/// route → view on demand.
///
/// Owns both the FeatureHost view lifts (parallel to the behavior lifts in
/// `Store+App.swift`) and the root view construction (parallel to how
/// `FeatureHost` / `@BoundTo` wires ViewModel + View).
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

    /// Builds the root `AppRootView`, wiring the `NavigationFeature.ViewModel`
    /// (same pattern as `FeatureHost` / `@BoundTo`).
    public var rootView: some View {
        AppRootView(
            viewModel: NavigationFeature.ViewModel(
                store: store.projection(
                    action: AppAction.prism.navigation.review,
                    state:  AppState.lens.navigation.get
                )
            )
        ) {
            view(for: .home)
                .navigationDestination(for: AppRoute.self) { route in
                    view(for: route)
                }
        }
    }

    // MARK: - Route → View

    /// Produces the view for `route`, lifting each `FeatureHost` against the
    /// captured store — mirrors the behavior lifts in `Store+App.swift`.
    public func view(for route: AppRoute) -> some View {
        route.module().view(for: store)
    }
}
