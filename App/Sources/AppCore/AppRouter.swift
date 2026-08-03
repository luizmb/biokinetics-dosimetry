import AppDomain
import CalculatorFeature
import EditorFeature
import HomeFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftUI

/// Turns a route into a screen — **the boundary the `World` stops at**.
///
/// ``AppFeature`` constructs one (it is the only thing holding the `World`) and hands it to the root
/// view. The view can therefore render a destination without ever naming `World`, naming a feature
/// type, or knowing how a child is built: it knows `AppRoute` and gets back an opaque `View`.
///
/// Every screen is built from the **same** `AppScopes` declaration that drives the behavior fold, so a
/// screen's action prism, its slice of state, and its environment narrowing are stated once and cannot
/// drift apart between the two uses.
///
/// Nothing is cached. `destination(for:)` runs per visible route, projecting the child's store and
/// narrowing `World` on the spot — a screen off the stack has no store, no view and no environment.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@MainActor
public struct AppRouter {
    private let store: MainStoreType
    private let world: World

    init(store: MainStoreType, world: World) {
        self.store = store
        self.world = world
    }

    /// The root screen — always on screen, so a total lift rather than an affine one.
    public func root() -> some View {
        AppScopes.home.view(of: HomeFeature.self, from: store, world: world)
    }

    /// The screen for `route`. `@ViewBuilder` keeps the concrete per-route types without `AnyView`.
    @ViewBuilder
    public func destination(for route: AppRoute) -> some View {
        switch route {
        case .editor:     AppScopes.editor.pushedView(of: EditorFeature.self, from: store, world: world)
        case .calculator: AppScopes.calculator.pushedView(of: CalculatorFeature.self, from: store, world: world)
        }
    }
}

// MARK: - Building a view from an affine scope

/// The affine counterpart of `Relay.Scope.view(of:from:world:)`, which needs a *total* state lane and so
/// cannot build a screen that lives in a stack element.
///
/// `transpose()` holds the last value steady while SwiftUI animates the pop, so a screen never blanks on
/// its way out; the outer `nil` then tears it down once the element is gone.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Relay.Scope where
    ActionStrategy: Relay.ActionAxis.EmbedsProtocol,
    StateStrategy: Relay.StateAxis.WritesProtocol,
    EnvironmentStrategy: Relay.EnvironmentAxis.NarrowsProtocol,
    ActionStrategy.Global == Action,
    StateStrategy.Global == State,
    EnvironmentStrategy.Global == Environment {
    @MainActor @ViewBuilder
    func pushedView<F: ViewFactory>(
        of _: F.Type,
        from store: any StoreType<Action, State>,
        world: Environment
    ) -> some View
    where F.Action == ActionStrategy.Local, F.State == StateStrategy.Local, F.Environment == EnvironmentStrategy.Local {
        if let screen = store.projection(action: action.review, state: state.preview).transpose() {
            F.view(store: screen, environment: environment.narrow(world))
        }
    }
}
