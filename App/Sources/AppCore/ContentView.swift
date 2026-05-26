import AppDomain
import CalculatorFeature
import EditorFeature
import HomeFeature
import NavigationFeature
import Observation
import SwiftRex
import SwiftRexArchitecture
import SwiftUI

// MARK: - AppRootViewModel

/// A bag of feature ViewModels, one per routable destination.
///
/// Each VM is created by projecting the app store down to its feature's
/// narrow action/state slice — the same double-projection the `@ViewModel`
/// macro generates internally. All subscription logic (path tracking,
/// dispatch wiring, token lifetimes) lives inside each feature's own VM.
@Observable
@MainActor
public final class AppRootViewModel {

    public let navigationVM:  NavigationFeature.ViewModel
    public let homeVM:        HomeFeature.ViewModel
    public let editorVM:      EditorFeature.ViewModel
    public let calculatorVM:  CalculatorFeature.ViewModel

    public init(store: Store<AppAction, AppState, World>) {
        navigationVM = NavigationFeature.ViewModel(
            store: store
                .projection(action: AppAction.prism.navigation.review,
                            state:  AppState.lens.navigation.get)
                .projection(action: NavigationFeature.mapAction,
                            state:  NavigationFeature.mapState)
        )
        homeVM = HomeFeature.ViewModel(
            store: store
                .projection(action: AppAction.prism.home.review,
                            state:  AppState.lens.home.get)
                .projection(action: HomeFeature.mapAction,
                            state:  HomeFeature.mapState)
        )
        editorVM = EditorFeature.ViewModel(
            store: store
                .projection(action: AppAction.prism.editor.review,
                            state:  AppState.lens.editor.get)
                .projection(action: EditorFeature.mapAction,
                            state:  EditorFeature.mapState)
        )
        calculatorVM = CalculatorFeature.ViewModel(
            store: store
                .projection(action: AppAction.prism.calculator.review,
                            state:  AppState.lens.calculator.get)
                .projection(action: CalculatorFeature.mapAction,
                            state:  CalculatorFeature.mapState)
        )
    }
}

// MARK: - AppRootView

/// Root navigation view. Reads only from `viewModel` — no store, no projections.
public struct AppRootView: View {
    let viewModel: AppRootViewModel

    public init(viewModel: AppRootViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack(
            path: Binding(
                get: { viewModel.navigationVM.path },
                set: { viewModel.navigationVM.dispatch(.setPath($0)) }
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
