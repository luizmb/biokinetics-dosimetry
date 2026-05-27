import AppDomain
import CalculatorFeature
import EditorFeature
import FP
import HomeFeature
import NavigationFeature
import SwiftRex
import SwiftRexArchitecture

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

public typealias MainStoreType = any StoreType<AppAction, AppState>
public typealias MainStore = Store<AppAction, AppState, World>

// MARK: - Store conveniences

public extension MainStore {

    /// Builds the app store wired to the given environment.
    /// Call `.app(environment: .live)` at the entry point; pass a mock environment in tests.
    @MainActor static func app(world: World) -> MainStoreType {
        Store(
            initial: AppState(),
            behavior: NavigationFeature.behavior().lift()
                <> Module.home.lift().behavior
                <> Module.editor.lift().behavior
                <> Module.calculator.lift().behavior
                <> bridgeBehavior(),
            environment: world
        )
    }

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
