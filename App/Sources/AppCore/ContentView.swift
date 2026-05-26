import CalculatorFeature
import EditorFeature
import Observation
import SwiftRex
import SwiftRexArchitecture
import SwiftUI

// MARK: - AppRootViewModel

/// Projects the full app store into everything `AppRootView` needs.
///
/// Takes `Store<AppAction, AppState, World>` once in `init`, creates all sub-feature
/// ViewModels from it, and subscribes to the navigation path. The view holds only
/// this ViewModel — no raw store, no inline projections in `body`.
@Observable
@MainActor
public final class AppRootViewModel {

    // MARK: Navigation path (observed)

    public var path: [AppRoute] = []

    // MARK: Sub-feature ViewModels (stable, created once)

    public let homeVM:       HomeFeature.ViewModel
    public let editorVM:     EditorFeature.ViewModel
    public let calculatorVM: CalculatorFeature.ViewModel

    // MARK: Private wiring

    @ObservationIgnored private var _dispatch: @MainActor @Sendable (NavigationFeature.ViewModel.ViewAction, ActionSource) -> Void = { _, _ in }
    @ObservationIgnored private var _token: SubscriptionToken?

    public init(store: Store<AppAction, AppState, World>) {
        // Navigation path — project twice: AppAction→NavigationAction, then →ViewAction
        let navStore = store
            .projection(
                action: AppAction.prism.navigation.review,
                state:  AppState.lens.navigation.get
            )
            .projection(
                action: NavigationFeature.mapAction,
                state:  NavigationFeature.mapState
            )

        // Phase 1: initialize ALL stored properties before self can appear in any closure
        path      = navStore.state.path
        _dispatch = navStore.dispatch
        _token    = nil   // will be replaced in phase 2

        // Sub-feature ViewModels — each gets its own narrow projection
        homeVM = HomeFeature.ViewModel(
            store: store.projection(
                action: AppAction.prism.home.review,
                state:  AppState.lens.home.get
            ).projection(
                action: HomeFeature.mapAction,
                state:  HomeFeature.mapState
            )
        )

        editorVM = EditorFeature.ViewModel(
            store: store.projection(
                action: AppAction.prism.editor.review,
                state:  AppState.lens.editor.get
            ).projection(
                action: EditorFeature.mapAction,
                state:  EditorFeature.mapState
            )
        )

        calculatorVM = CalculatorFeature.ViewModel(
            store: store.projection(
                action: AppAction.prism.calculator.review,
                state:  AppState.lens.calculator.get
            ).projection(
                action: CalculatorFeature.mapAction,
                state:  CalculatorFeature.mapState
            )
        )

        // Phase 2: all stored properties initialized — safe to capture self
        _token = navStore.observe(didChange: { [weak self] in
            guard let self else { return }
            let new = navStore.state.path
            if self.path != new { self.path = new }
        })
    }

    public func dispatch(_ action: NavigationFeature.ViewModel.ViewAction) {
        _dispatch(action, ActionSource(file: #file, function: #function, line: #line))
    }
}

// MARK: - AppRootView

/// Root navigation view. Only accesses `viewModel` — all store wiring lives in
/// `AppRootViewModel.init`.
public struct AppRootView: View {
    let viewModel: AppRootViewModel

    public init(viewModel: AppRootViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack(
            path: Binding(
                get: { viewModel.path },
                set: { viewModel.dispatch(.setPath($0)) }
            )
        ) {
            HomeView(viewModel: viewModel.homeVM)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .home:
                        HomeView(viewModel: viewModel.homeVM)
                    case .editor:
                        EditorView(viewModel: viewModel.editorVM)
                    case .calculator:
                        CalculatorView(viewModel: viewModel.calculatorVM)
                    }
                }
        }
    }
}
