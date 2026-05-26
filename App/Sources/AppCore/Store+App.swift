import AppDomain
import CalculatorFeature
import EditorFeature
import FP
import HomeFeature
import NavigationFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftUI

// MARK: - AppState

/// Flat application state. Every feature is a sibling — none is parent to another.
@Lenses
public struct AppState: Sendable {
    public var navigation: NavigationFeature.State = .init()
    public var home:       HomeFeature.State       = HomeFeature.initialState()
    public var editor:     EditorFeature.State     = EditorFeature.initialState()
    public var calculator: CalculatorFeature.State = CalculatorFeature.initialState()
    public init() {}
}

// MARK: - AppAction

/// Flat action space. Navigation actions are their own case, not a parent wrapper.
@Prisms @dynamicMemberLookup
public enum AppAction: Sendable {
    case navigation(NavigationFeature.Action)
    case home(HomeFeature.Action)
    case editor(EditorFeature.Action)
    case calculator(CalculatorFeature.Action)
}

// MARK: - Store conveniences

public extension Store where Action == AppAction, State == AppState, Environment == World {

    /// Builds the app store wired to the given environment.
    /// Call `.app(environment: .live)` at the entry point; pass a mock environment in tests.
    @MainActor static func app(environment: World) -> Store<AppAction, AppState, World> {
        Store(
            initial: AppState(),
            behavior: navigationBehavior()
                <> homeBehavior()
                <> editorBehavior()
                <> calculatorBehavior()
                <> bridgeBehavior(),
            environment: environment
        )
    }

    /// The root navigation view, ready to be placed in a `WindowGroup`.
    @MainActor var rootView: some View {
        AppRootView(viewModel: AppRootViewModel(store: self))
    }
}

// MARK: - Lifted sub-behaviors

private func navigationBehavior() -> Behavior<AppAction, AppState, World> {
    NavigationFeature.behavior()
        .lift(
            action:      AppAction.prism.navigation,
            state:       AppState.lens.navigation,
            environment: ignore
        )
}

private func homeBehavior() -> Behavior<AppAction, AppState, World> {
    FeatureHost.home.behavior
        .lift(
            action:      AppAction.prism.home,
            state:       AppState.lens.home,
            environment: \.xmlDecoder >>> HomeFeature.Environment.init
        )
}

private func editorBehavior() -> Behavior<AppAction, AppState, World> {
    FeatureHost.editor.behavior
        .lift(
            action:      AppAction.prism.editor,
            state:       AppState.lens.editor,
            environment: ignore
        )
}

private func calculatorBehavior() -> Behavior<AppAction, AppState, World> {
    FeatureHost.calculator.behavior
        .lift(
            action:      AppAction.prism.calculator,
            state:       AppState.lens.calculator,
            environment: \.solver >>> CalculatorFeature.Environment.init
        )
}

// MARK: - Bridge behavior

/// Intercepts Home actions that imply navigation and dispatches the appropriate
/// route push + target-feature document load. Lives here — not inside NavigationFeature —
/// because NavigationFeature is intentionally unaware of other features.
private func bridgeBehavior() -> Behavior<AppAction, AppState, World> {
    Behavior { dispatched, _ in
        switch dispatched.action {
        case let .home(.edit(document: doc)):
            .reduce { $0.editor.document = doc }
            .produce(const(.just(.navigation(.setPath([.editor])))))

        case let .home(.calculate(document: doc)):
            .reduce { $0.calculator.document = doc }
            .produce(const(.just(.navigation(.setPath([.calculator])))))

        default:
            .doNothing
        }
    }
}
