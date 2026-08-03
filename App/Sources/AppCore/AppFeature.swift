import AppDomain
import CalculatorFeature
import CoreFP
import CoreFPOperators
import EditorFeature
import FP
import HomeFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftRexOperators
import SwiftUI

// MARK: - AppFeature

/// The app is a `Feature` like any other: it owns state, actions and a behavior, and it builds its own
/// view. Nothing about the root is special-cased — which is the point. The root used to hand a bare
/// `Store` to a view, and because `Store` is not `@Observable`, the stack silently never re-rendered.
/// Going through the standard `Feature` machinery means the view store is built exactly the way every
/// other screen's is, so that failure is no longer expressible here.
///
/// It is also the app's coordinator: it holds the `World`, constructs the ``AppRouter``, and injects it
/// into the root view. Child features are created by that router on demand and never cached.
@Feature(strategy: .observationSimple)
public enum AppFeature {

    // MARK: - State

    public struct State: Sendable, Equatable {
        /// The root screen — always on screen, so never optional.
        public var home: HomeFeature.State

        /// The pushed screens, each carrying its own state. One source of truth: there is no parallel
        /// table to keep in step, so a route and its data cannot disagree.
        public var path: [StackEntry]

        public init() {
            home = HomeFeature.initialState(with: ())
            path = []
        }
    }

    // MARK: - Action

    @Prisms
    public enum Action: Sendable {
        case appLaunch
        /// The debounced "the editor has gone quiet" tick. See ``autosaveEditedDocumentBehavior()``.
        case autosaveEditor
        case navigation(NavigationAction)
        case home(HomeFeature.Action)
        case editor(EditorFeature.Action)
        case calculator(CalculatorFeature.Action)
    }

    // MARK: - Environment

    public typealias Environment = World

    // No `ViewState`/`ViewAction`: the macro aliases them to `State`/`Action`, so the root view's store
    // is `ViewStore<State, Action>` — the whole app, which is what a router needs to project children.

    // MARK: - Lifecycle

    public static func initialState(with _: Void) -> State { .init() }

    // MARK: - View
    //
    // Hand-written rather than `typealias Content`: the generated `view()` passes only the view store,
    // and the root view also needs its router. This is the one place holding the `World`, so it is the
    // one place that can build a router — and the `World` goes no further.

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @MainActor
    public static func view(store: any StoreType<Action, State>, environment: World) -> some View {
        AppRootView(
            viewStore: ViewStore(store),
            router: AppRouter(store: store, world: environment)
        )
    }

    // MARK: - Behavior

    public static func behavior() -> Behavior<Action, State, World> {
        // Each feature's own wiring sits with it: the lift, then the actions it sends onward. Reading a
        // feature's row tells you everything it participates in, without a separate bridge to
        // cross-check. The document flows straight through the push — no reducer reaches into a
        // sibling's state to seed it, because the screen is built from the request.
        navigationBehavior()
        <> autosaveEditedDocumentBehavior()

        <> AppScopes.home.behavior(of: HomeFeature.self)
            .on(.action(\.appLaunch), dispatch: .action(review: const(.home(.loadDocuments))))
            .on(.action(\.home.edit), dispatch: .action(\.navigation.push.editor))
            .on(.action(\.home.calculate), dispatch: .action(\.navigation.push.calculator))

        <> AppScopes.editor.behavior(of: EditorFeature.self)

        <> AppScopes.calculator.behavior(of: CalculatorFeature.self)
    }
}

// Familiar spellings for the app triad — `AppFeature.State` everywhere would only add noise.
public typealias AppState = AppFeature.State
public typealias AppAction = AppFeature.Action
public typealias MainStoreType = any StoreType<AppAction, AppState>
public typealias MainStore = Store<AppAction, AppState, World>

// MARK: - The path, as SwiftUI sees it

public extension AppState {
    /// The `Hashable` identities SwiftUI navigates by. Read-only — the path is the truth, this is a view
    /// of it. A screen's data can change all it likes without changing which screen it is.
    var routes: [AppRoute] { path.map(\.route) }
}

// MARK: - Store factory

public extension MainStore {

    /// Builds the app store wired to the given environment.
    /// Call `.app(world: .real)` at the entry point; pass a fake `World` in tests.
    @MainActor static func app(world: World) -> MainStoreType {
        Store(
            initial: AppState(),
            behavior: AppFeature.behavior(),
            environment: world
        )
        .dispatching(.appLaunch)
    }

}

private extension Store<AppAction, AppState, World> {
    func dispatching(
        _ action: AppAction,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Self {
        dispatch(action, source: .init(file: file, function: function, line: line))
        return self
    }
}

// MARK: - Feature scopes
//
// One declaration per feature carrying all three axes — action, state, environment — so the same value
// drives the behavior fold and the router. A pushed screen's state axis is **affine**: it focuses the
// `path` element the screen lives in, reading and writing through the same prism, so there is no derived
// copy and nothing to keep in step.

public enum AppScopes: Rig {
    public typealias Action = AppAction
    public typealias State = AppState
    public typealias Environment = World

    // `ScopeOf<AppScopes>` pins the app triad (`Action`/`State`/`Environment`) as the entry point, so each
    // declaration is just `.action(\.x).state(…).environment(…)` — no explicit witnesses.

    public static let home = ScopeOf<AppScopes>
        .action(\.home)
        .state(\.home)
        .environment(fanout(
            \.xmlDecoder, \.jsonDecoder, \.newId, \.seedId,
            \.saveDocument, \.loadAllDocuments, \.deleteDocument
        ) >>> HomeModule.Environment.init)

    public static let editor = ScopeOf<AppScopes>
        .action(\.editor)
        .state(preview: topmost(StackEntry.prism.editor), set: replacing(StackEntry.prism.editor))
        .environment(\.newId >>> EditorFeature.Environment.init)

    public static let calculator = ScopeOf<AppScopes>
        .action(\.calculator)
        .state(preview: topmost(StackEntry.prism.calculator), set: replacing(StackEntry.prism.calculator))
        .environment(fanout(\.solver, \.formatDouble, \.parseDouble) >>> CalculatorFeature.Environment.init)
}

// MARK: - The affine focus a pushed screen lives behind
//
// Both halves go through the same prism, so a read and a write can never disagree about which element
// they mean. `replacing` only ever overwrites an element that is already there — it cannot append, so a
// child behavior can never conjure a screen navigation did not push.

private func topmost<S>(_ prism: Prism<StackEntry, S>) -> @Sendable (AppState) -> S? {
    { $0.path.compactMap(prism.preview).last }
}

private func replacing<S>(_ prism: Prism<StackEntry, S>) -> @Sendable (AppState, S) -> AppState {
    { state, screen in
        guard let index = state.path.lastIndex(where: { prism.preview($0) != nil }) else { return state }
        var updated = state
        updated.path[index] = prism.review(screen)
        return updated
    }
}
