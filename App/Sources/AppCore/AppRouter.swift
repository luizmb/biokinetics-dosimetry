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
/// type, or knowing how a child is built: it passes its view store and a route, and gets back an
/// opaque `View`.
///
/// Every screen is built from the **same** `AppScopes` declaration that drives the behavior fold, so a
/// screen's action prism, its slice of state, and its environment narrowing are stated once and cannot
/// drift apart between the two uses.
///
/// Nothing is cached. `destination(for:from:)` runs per visible route, deriving the child's store and
/// narrowing `World` on the spot — a screen off the stack has no store, no view and no environment.
/// A pushed screen lives behind an affine scope: `view(of:from:world:)` is `nil` once its element is
/// gone, and holds the last value while SwiftUI animates the pop, so a screen never blanks on its way out.
@MainActor
public struct AppRouter {
    private let world: World

    init(world: World) {
        self.world = world
    }

    /// The root screen — always on screen, so a total lift rather than an affine one.
    public func root(from viewStore: ViewStore<AppAction, AppState>) -> some View {
        AppScopes.home.view(of: HomeFeature.self, from: viewStore, world: world)
    }

    /// The screen for `route`. `@ViewBuilder` keeps the concrete per-route types without `AnyView`.
    @ViewBuilder
    public func destination(for route: AppRoute, from viewStore: ViewStore<AppAction, AppState>) -> some View {
        switch route {
        case .editor:
            if let editor = AppScopes.editor.view(of: EditorFeature.self, from: viewStore, world: world) { editor }
        case .calculator:
            if let calculator = AppScopes.calculator.view(of: CalculatorFeature.self, from: viewStore, world: world) { calculator }
        }
    }
}
