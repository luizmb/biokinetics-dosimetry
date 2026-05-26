import CalculatorFeature
import EditorFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftUI

// MARK: - AppRootView

/// Root navigation view for the entire application.
///
/// Holds `navVM` as a `let` — it is a pure proxy to the store with no state of its
/// own, so recreating it on re-render is correct and cheap.
public struct AppRootView: View {
    let store: Store<AppAction, AppState, World>
    let navVM: NavigationFeature.ViewModel

    public init(store: Store<AppAction, AppState, World>) {
        self.store = store
        self.navVM = NavigationFeature.ViewModel(
            store: store
                .projection(
                    action: AppAction.prism.navigation.review,
                    state:  AppState.lens.navigation.get
                )
                .projection(
                    action: NavigationFeature.mapAction,
                    state:  NavigationFeature.mapState
                )
        )
    }

    public var body: some View {
        NavigationStack(
            path: Binding(
                get: { navVM.path },
                set: { navVM.dispatch(.setPath($0)) }
            )
        ) {
            FeatureHost.home.view(for:
                store.projection(
                    action: AppAction.prism.home.review,
                    state:  AppState.lens.home.get
                )
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .home:
                    FeatureHost.home.view(for:
                        store.projection(
                            action: AppAction.prism.home.review,
                            state:  AppState.lens.home.get
                        )
                    )
                case .editor:
                    FeatureHost.editor.view(for:
                        store.projection(
                            action: AppAction.prism.editor.review,
                            state:  AppState.lens.editor.get
                        )
                    )
                case .calculator:
                    FeatureHost.calculator.view(for:
                        store.projection(
                            action: AppAction.prism.calculator.review,
                            state:  AppState.lens.calculator.get
                        )
                    )
                }
            }
        }
    }
}
