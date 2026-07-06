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
            behavior: NavigationFeature.behavior().lift(action: \.navigation, state: \.navigation, environment: { _ in () })
                <> Scope<AppAction, AppState, World, HomeFeature>.home.behavior
                <> Scope<AppAction, AppState, World, EditorFeature>.editor.behavior
                <> Scope<AppAction, AppState, World, CalculatorFeature>.calculator.behavior
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
            AppAction.prism.home >>> HomeModule.Action.prism.edit,
            dispatch: { doc in .navigation(.setPath([.editor])) },
            reduce: { doc, state in state.editor.document = doc }
        )
        .on(
            AppAction.prism.home >>> HomeModule.Action.prism.calculate,
            dispatch: { doc in .navigation(.setPath([.calculator])) },
            reduce: { doc, state in
                state.calculator.document = doc
                state.calculator.results = nil   // clear stale results from a previous document
                state.calculator.error = nil
            }
        )
}

// MARK: - Feature scopes

public extension Scope<AppAction, AppState, World, CalculatorFeature> {
    static var calculator: Self {
        Scope(
            CalculatorFeature.self,
            action: \.calculator,
            state: \.calculator,
            environment: { world in
                CalculatorFeature.Environment(
                    solve:        world.solver,
                    formatDouble: world.formatDouble,
                    parseDouble:  world.parseDouble
                )
            }
        )
    }
}

public extension Scope<AppAction, AppState, World, EditorFeature> {
    static var editor: Self {
        Scope(
            EditorFeature.self,
            action: \.editor,
            state: \.editor,
            environment: { world in EditorFeature.Environment(newId: world.newId) }
        )
    }
}

public extension Scope<AppAction, AppState, World, HomeFeature> {
    static var home: Self {
        Scope(
            HomeFeature.self,
            action: \.home,
            state: \.home,
            environment: { world in
                HomeModule.Environment(
                    xmlDecoder:       world.xmlDecoder,
                    jsonDecoder:      world.jsonDecoder,
                    newId:            world.newId,
                    seedId:           world.seedId,
                    saveDocument:     world.saveDocument,
                    loadAllDocuments: world.loadAllDocuments,
                    deleteDocument:   world.deleteDocument
                )
            }
        )
    }
}
