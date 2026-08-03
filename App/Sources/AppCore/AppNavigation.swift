import AppDomain
import CalculatorFeature
import EditorFeature
import SwiftRex
import SwiftRexArchitecture

// MARK: - Navigation action

/// The navigation vocabulary.
///
/// `push` carries a ``NavigationRequest`` — the *ask* ("open the editor on this document"), not the
/// screen itself. The reducer turns a request into a ``StackEntry``, which is what lets a feature
/// dispatch tacitly (`dispatch: .action(\.navigation.push.editor)`) while the reducer stays the only
/// thing that knows how a screen is built. A request is a transient action payload — never stored, so
/// it is not a second source of truth.
///
/// `setPath` is what `NavigationStack`'s binding delivers for every interactive change — back button,
/// back-swipe, pop-to-root — so user-driven and programmatic navigation land in the same reducer.
@Prisms
public enum NavigationAction: Sendable {
    case push(NavigationRequest)
    case pop
    case popToRoot
    case setPath([AppRoute])
}

// MARK: - The navigation behavior

/// The only writer of `path`.
///
/// There is no reconciliation step: nothing to seed after a push and nothing to discard after a pop,
/// because a screen's data lives in the element that was appended or removed.
func navigationBehavior() -> Behavior<AppAction, AppState, World> {
    .reduce { action, state in
        guard let navigation = AppAction.prism.navigation.preview(action) else { return }
        state.path = state.resolving(navigation)
    }
}

extension AppState {
    /// The stack `navigation` asks for. Pure and total — the single arbiter of the path, which keeps
    /// the rules testable without a store.
    func resolving(_ navigation: NavigationAction) -> [StackEntry] {
        switch navigation {
        case .push(let request):
            path + [entry(for: request)]

        case .pop:
            Array(path.dropLast())

        case .popToRoot:
            []

        case .setPath(let routes):
            // SwiftUI only ever shortens the path interactively. Folding to the longest matching prefix
            // is total: it cannot desynchronise, and an unexpected path simply truncates rather than
            // leaving `path` disagreeing with what is on screen.
            zip(path, routes)
                .prefix { $0.route == $1 }
                .map(\.0)
        }
    }

    /// Builds the stack entry a request asks for — by **construction**, so there is never a
    /// half-initialised screen for someone to finish assembling.
    func entry(for request: NavigationRequest) -> StackEntry {
        switch request {
        case .editor(let document):     .editor(EditorFeature.State(document: document))
        case .calculator(let document): .calculator(CalculatorFeature.State(document: document))
        }
    }
}
