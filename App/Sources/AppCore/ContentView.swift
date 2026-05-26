import CalculatorFeature
import EditorFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftUI

// MARK: - AppRootView

/// Root navigation view for the entire application.
///
/// The `NavigationFeature.ViewModel` is kept as `@State` because its `path` property
/// is the `@Observable` value that drives the `NavigationStack` binding — without stable
/// `@State` identity, path changes would not trigger re-renders.
///
/// Feature ViewModels (Home, Editor, Calculator) are created on demand by their
/// `FeatureHost.view(for:)` call. Because all state lives in the store (a singleton),
/// recreating the proxy ViewModel on each render is correct and cheap.
public struct AppRootView: View {
    let store: Store<AppAction, AppState, World>

    @State private var navVM: NavigationFeature.ViewModel

    public init(store: Store<AppAction, AppState, World>) {
        self.store = store
        _navVM = State(wrappedValue: NavigationFeature.ViewModel(
            store: store.projection(
                action: NavigationFeature.mapAction,
                state:  NavigationFeature.mapState
            )
        ))
    }

    public var body: some View {
        NavigationStack(
            path: Binding(
                get: { navVM.path },
                set: { navVM.dispatch(.setPath($0)) }
            )
        ) {
            FeatureHost.home.view(for:
                store.projection(action: AppAction.prism.home.review,
                                 state:  AppState.lens.home.get)
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .home:
                    FeatureHost.home.view(for:
                        store.projection(action: AppAction.prism.home.review,
                                         state:  AppState.lens.home.get)
                    )
                case .editor:
                    FeatureHost.editor.view(for:
                        store.projection(action: AppAction.prism.editor.review,
                                         state:  AppState.lens.editor.get)
                    )
                case .calculator:
                    FeatureHost.calculator.view(for:
                        store.projection(action: AppAction.prism.calculator.review,
                                         state:  AppState.lens.calculator.get)
                    )
                }
            }
        }
    }
}
