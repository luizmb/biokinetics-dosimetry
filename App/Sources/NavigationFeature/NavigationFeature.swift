import AppDomain
import SwiftRex
import SwiftRexArchitecture

// MARK: - NavigationFeature

/// Owns exactly one concern: the navigation stack path.
///
/// `State` is a single `path: [AppRoute]`. `Action` is `push` / `setPath`.
/// Everything else (home, editor, calculator state and cross-feature bridging)
/// lives at the `AppState` / `AppAction` level in `Store+App.swift`.
///
/// Because State ≡ ViewState and Action ≡ ViewAction for this feature,
/// both are typealiases — the mapping is the identity function.
public enum NavigationFeature {

    // MARK: - ViewModel

    @ViewModel
    public final class ViewModel {
        public struct ViewState: Sendable, Equatable {
            public var path: [AppRoute] = []
            public init() {}
        }

        @Prisms @dynamicMemberLookup
        public enum ViewAction: Sendable {
            /// Appends a single route to the navigation stack.
            case push(AppRoute)
            /// Replaces the entire path (used by SwiftUI back-navigation binding).
            case setPath([AppRoute])
        }
    }

    // MARK: - State / Action / Environment

    /// Identical to `ViewModel.ViewState` — no projection needed.
    public typealias State = ViewModel.ViewState
    /// Identical to `ViewModel.ViewAction` — no projection needed.
    public typealias Action = ViewModel.ViewAction

    public typealias Environment = Void

    // MARK: - Behavior

    public static func initialState() -> State { .init() }

    public static func behavior() -> Behavior<Action, State, Void> {
        .handle { action, _ in
            switch action.action {
            case .push(let route):   .reduce { $0.path.append(route) }
            case .setPath(let path): .reduce { $0.path = path }
            }
        }
    }
}
