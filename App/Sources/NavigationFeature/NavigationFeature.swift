import AppDomain
import SwiftRex
import SwiftRexArchitecture

// MARK: - NavigationFeature

/// Owns exactly one concern: the navigation stack path.
///
/// `State` is a single `path: [AppRoute]`. `Action` is `push` / `setPath`.
/// Everything else (home, editor, calculator state and cross-feature bridging)
/// lives at the `AppState` / `AppAction` level in `AppTypes.swift`.
public enum NavigationFeature {

    // MARK: - Action

    @Prisms @dynamicMemberLookup
    public enum Action: Sendable {
        /// Appends a single route to the navigation stack.
        case push(AppRoute)
        /// Replaces the entire path (used by SwiftUI back-navigation binding).
        case setPath([AppRoute])
    }

    // MARK: - State

    public struct State: Sendable, Equatable {
        public var path: [AppRoute] = []
        public init() {}
    }

    // MARK: - Environment

    public typealias Environment = Void

    // MARK: - ViewModel

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
