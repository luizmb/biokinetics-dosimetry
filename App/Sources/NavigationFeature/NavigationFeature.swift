import AppDomain
import CoreFP
import FPMacros
import SwiftRex
import SwiftRexArchitecture

// MARK: - NavigationFeature

/// Owns exactly one concern: the navigation stack path.
///
/// `State` is a single `path: [AppRoute]`. `Action` is `push` / `setPath`.
/// Everything else (home, editor, calculator state and cross-feature bridging)
/// lives at the `AppState` / `AppAction` level in `Store+App.swift`.
///
/// Logic-only (no view): a plain enum with `behavior()`, lifted into the app store directly.
public enum NavigationFeature {

    public struct State: Sendable, Equatable {
        public var path: [AppRoute] = []
        public init() {}
    }

    @Prisms
    public enum Action: Sendable {
        /// Appends a single route to the navigation stack.
        case push(AppRoute)
        /// Replaces the entire path (used by SwiftUI back-navigation binding).
        case setPath([AppRoute])
    }

    public typealias Environment = Void

    public static func initialState(with _: Void) -> State { .init() }

    public static func behavior() -> Behavior<Action, State, Void> {
        .handle { action, _ in
            switch action {
            case .push(let route):   .reduce { $0.path.append(route) }
            case .setPath(let path): .reduce { $0.path = path }
            }
        }
    }
}
