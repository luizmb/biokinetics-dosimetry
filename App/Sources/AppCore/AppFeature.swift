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
    public var home:       HomeFeature.State       = HomeFeature.initialState(with: ())
    public var editor:     EditorFeature.State     = EditorFeature.initialState(with: ())
    public var calculator: CalculatorFeature.State = CalculatorFeature.initialState(with: ())
    public init() {}
}

// MARK: - AppAction

/// Flat action space. Navigation actions are their own case, not a parent wrapper.
@Prisms
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
        let store = Store(
            initial: AppState(),
            behavior: NavigationFeature.behavior().lift(.action(\.navigation).state(\.navigation).environment(ignore))
                <> AppScopes.home.behavior(of: HomeFeature.self)
                <> AppScopes.editor.behavior(of: EditorFeature.self)
                <> AppScopes.calculator.behavior(of: CalculatorFeature.self)
                <> bridgeBehavior()
                <> saveEditorOnBackBehavior(),
            environment: world
        )
        // Load persisted documents as the very first action.
        store.dispatch(.home(.loadDocuments))
        return store
    }

}

// MARK: - Bridge behavior

/// When the user navigates back from the Editor to Home, save the edited document.
/// Dispatches `.home(.saveDocument)` which both updates the Home list and persists to disk.
private func saveEditorOnBackBehavior() -> Behavior<AppAction, AppState, World> {
    .handle { action, context in
        guard case .navigation(.setPath(let newPath)) = action,
              newPath.isEmpty,
              context.stateBefore?.navigation.path.last == .editor,
              let doc = context.stateBefore?.editor.document
        else { return .doNothing }
        return .produce { _ in .just(.home(.saveDocument(doc))) }
    }
}

/// Intercepts Home actions that imply navigation and dispatches the appropriate
/// route push + target-feature document load. Lives here — not inside NavigationFeature —
/// because NavigationFeature is intentionally unaware of other features.
private func bridgeBehavior() -> Behavior<AppAction, AppState, World> {
    Behavior<AppAction, AppState, World>.identity
        .on(
            .action(\.home.edit),
            dispatch: .action(review: const(.navigation(.setPath([.editor])))),
            reduce: { doc, state in state.editor.document = doc }
        )
        .on(
            .action(\.home.calculate),
            dispatch: .action(review: const(.navigation(.setPath([.calculator])))),
            reduce: { doc, state in
                state.calculator.document = doc
                state.calculator.results = nil   // clear stale results from a previous document
                state.calculator.error = nil
            }
        )
}

// MARK: - Feature scopes

public enum AppScopes: Rig {
    public typealias Action = AppAction
    public typealias State = AppState
    public typealias Environment = World

    // Total-state scope shape pinned to the app triad (duplex `Prism` / total `ReadsWrites` / `Narrows`).
    // Annotating a scope `Global<_,_,_>` roots the bare optics, so each declares as
    // `.action(\.x).state(\.x).environment(…)` with no explicit witnesses.
    public typealias Global<A, S, E> = Relay.Scope<
        Relay.ActionAxis.Prism<Action, A>,
        Relay.StateAxis.ReadsWrites<State, S>,
        Relay.EnvironmentAxis.Narrows<Environment, E>
    >

    public static let calculator: Global<_, _, _> =
        .action(\.calculator).state(\.calculator)
        .environment(fanout(
            keypaths: \.solver, \.formatDouble, \.parseDouble,
            into: CalculatorFeature.Environment.init
        ))

    public static let editor: Global<_, _, _> =
        .action(\.editor).state(\.editor)
        .environment(\.newId >>> EditorFeature.Environment.init)

    public static let home: Global<_, _, _> =
        .action(\.home).state(\.home)
        .environment(fanout(
            keypaths: \.xmlDecoder, \.jsonDecoder, \.newId, \.seedId,
                      \.saveDocument, \.loadAllDocuments, \.deleteDocument,
            into: HomeModule.Environment.init
        ))
}
