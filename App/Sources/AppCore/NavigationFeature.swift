import AppDomain
import CalculatorFeature
import Core
import EditorFeature
import FP
import SwiftRex
import SwiftRexArchitecture

// MARK: - NavigationFeature

/// The top-level composition feature. Its `Action` and `State` *are* `AppAction` and
/// `AppState` (re-exported as typealiases in `AppTypes.swift`). Its `ViewModel` exposes
/// only the navigation path, so `ContentView` re-renders exclusively when the path
/// changes — not on every sub-feature state mutation.
///
/// `behavior()` combines all sub-feature behaviors *and* the cross-cutting navigation
/// logic that intercepts `home(.edit)` / `home(.calculate)` and pushes the appropriate
/// route after pre-loading the target feature's document.
///
/// `NavigationFeature` intentionally does NOT use the `@Feature` macro: that macro
/// requires a `Content` typealias pointing to a SwiftUI view, but this feature's
/// navigation view (`AppRootView`) owns its own ViewModel as `@State` — bypassing the
/// `FeatureHost.view(for:)` creation path so every feature ViewModel is instantiated
/// exactly once, lazily, by the view that needs it.
public enum NavigationFeature {

    // MARK: - Action

    @Prisms @dynamicMemberLookup
    public enum Action: Sendable {
        case home(HomeFeature.Action)
        case editor(EditorFeature.Action)
        case calculator(CalculatorFeature.Action)
        /// Appends a single route to the navigation stack.
        case push(AppRoute)
        /// Replaces the entire navigation stack path (used by SwiftUI back-navigation binding).
        case setPath([AppRoute])
    }

    // MARK: - State

    @Lenses
    public struct State: Sendable {
        /// The navigation stack path — drives `NavigationStack(path:)` in `AppRootView`.
        public var path: [AppRoute] = []
        public var home: HomeFeature.State = HomeFeature.initialState()
        public var editor: EditorFeature.State = EditorFeature.initialState()
        public var calculator: CalculatorFeature.State = CalculatorFeature.initialState()
        public init() {}
    }

    // MARK: - Environment

    public typealias Environment = World

    // MARK: - ViewModel

    /// Exposes only `path` — `@Observable` field-level tracking means `AppRootView`
    /// invalidates only when the path array changes, regardless of other state mutations.
    @ViewModel
    public final class ViewModel {
        public struct ViewState: Sendable, Equatable {
            public var path: [AppRoute] = []
        }

        @dynamicMemberLookup
        public enum ViewAction: Sendable {
            case push(AppRoute)
            case setPath([AppRoute])
        }
    }

    // MARK: - Mappings

    public static let mapState: @MainActor @Sendable (State) -> ViewModel.ViewState = { state in
        .init(path: state.path)
    }

    public static let mapAction: @Sendable (ViewModel.ViewAction) -> Action = { va in
        switch va {
        case .push(let route):   .push(route)
        case .setPath(let path): .setPath(path)
        }
    }

    // MARK: - Lifecycle

    public static func initialState() -> State { .init() }

    public static func behavior() -> Behavior<Action, State, Environment> {
        homeBehavior()
        <> editorBehavior()
        <> calculatorBehavior()
        <> navigationBehavior()
    }
}

// MARK: - Sub-behaviors

private func homeBehavior() -> Behavior<NavigationFeature.Action, NavigationFeature.State, World> {
    FeatureHost.home.behavior
        .lift(
            action:      NavigationFeature.Action.prism.home,
            state:       NavigationFeature.State.lens.home,
            environment: \.xmlDecoder >>> HomeFeature.Environment.init
        )
}

private func editorBehavior() -> Behavior<NavigationFeature.Action, NavigationFeature.State, World> {
    FeatureHost.editor.behavior
        .lift(
            action:      NavigationFeature.Action.prism.editor,
            state:       NavigationFeature.State.lens.editor,
            environment: ignore
        )
}

private func calculatorBehavior() -> Behavior<NavigationFeature.Action, NavigationFeature.State, World> {
    FeatureHost.calculator.behavior
        .lift(
            action:      NavigationFeature.Action.prism.calculator,
            state:       NavigationFeature.State.lens.calculator,
            environment: const(.live)
        )
}

/// Cross-cutting navigation: intercepts `home(.edit)` / `home(.calculate)` and pushes the
/// appropriate route, pre-seeding the target feature's document in state. Also handles
/// the raw `push` / `setPath` actions that the `AppRootView` path binding dispatches.
private func navigationBehavior() -> Behavior<NavigationFeature.Action, NavigationFeature.State, World> {
    Behavior { dispatched, _ in
        switch dispatched.action {
        case let .home(.edit(document: doc)):
            .reduce { $0.editor.document = doc }
            .produce(const(.just(.setPath([.editor]))))

        case let .home(.calculate(document: doc)):
            .reduce { $0.calculator.document = doc }
            .produce(const(.just(.setPath([.calculator]))))

        case .push(let route):
            .reduce { $0.path.append(route) }

        case .setPath(let path):
            .reduce { $0.path = path }

        default:
            .doNothing
        }
    }
}
