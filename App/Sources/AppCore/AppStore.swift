import AppDomain
import EditorFeature
import CalculatorFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftUI

// MARK: - AppCoordinator

/// Owns the global `Store` and all ViewModels used by `ContentView` and the
/// `NavigationStack` destination factory.
@MainActor
public final class AppCoordinator {
    public let store: Store<AppAction, AppState, AppEnvironment>

    /// The merged home + navigation ViewModel that drives the root navigation stack.
    public let homeVM: HomeFeature.ViewModel

    let editorStore:     StoreProjection<EditorFeature.Action,     EditorFeature.State>
    let calculatorStore: StoreProjection<CalculatorFeature.Action, CalculatorFeature.State>

    public init() {
        #if DEBUG
        let env = AppEnvironment.mock
        #else
        let env = AppEnvironment.live
        #endif

        let homeBehavior = FeatureHost.home.behavior
            .lift(
                action:      AppAction.prism.home,
                state:       AppState.lens.home,
                environment: { (e: AppEnvironment) in
                    HomeFeature.Environment(parseXML: e.parseXML)
                }
            )

        let editorBehavior = FeatureHost.editor.behavior
            .lift(
                action:      AppAction.prism.editor,
                state:       AppState.lens.editor,
                environment: { (_: AppEnvironment) in
                    EditorFeature.Environment()
                }
            )

        let calculatorBehavior = FeatureHost.calculator.behavior
            .lift(
                action:      AppAction.prism.calculator,
                state:       AppState.lens.calculator,
                environment: { (_: AppEnvironment) in
                    CalculatorFeature.Environment.live
                }
            )

        let s = Store(
            initial: AppState(),
            behavior: Behavior.combine(
                homeBehavior,
                Behavior.combine(editorBehavior, calculatorBehavior)
            ),
            environment: env
        )

        store = s

        homeVM = HomeFeature.ViewModel(
            store: s
                .projection(action: AppAction.prism.home.review,
                            state:  AppState.lens.home.get)
                .projection(action: HomeFeature.mapAction,
                            state:  HomeFeature.mapState)
        )

        editorStore = s.projection(
            action: AppAction.prism.editor.review,
            state:  AppState.lens.editor.get
        )
        calculatorStore = s.projection(
            action: AppAction.prism.calculator.review,
            state:  AppState.lens.calculator.get
        )
    }

    // MARK: - Navigation destination factory

    @ViewBuilder
    public func destination(for route: AppRoute) -> some View {
        switch route {
        case .editor(let doc):
            let _ = store.dispatch(AppAction.editor(.load(doc)))
            FeatureHost.editor.view(for: editorStore)

        case .calculator(let doc):
            let _ = store.dispatch(AppAction.calculator(.load(doc)))
            FeatureHost.calculator.view(for: calculatorStore)
        }
    }
}
