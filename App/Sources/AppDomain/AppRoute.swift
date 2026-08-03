import FPMacros

/// The identity of a screen on the navigation stack — **payload-free on purpose**.
///
/// `NavigationStack` keys its destinations by the path element's *value*, so a payload here would make
/// "the same screen showing different data" a different destination: SwiftUI would tear the screen down
/// and re-push it whenever that data changed. What a screen currently shows belongs to its own feature
/// state; a route only says *which* screen. Home — the root — is deliberately absent: it is not a
/// destination, so it can never be pushed on top of itself.
public enum AppRoute: Hashable, Sendable {
    case editor
    case calculator
}

/// An ask to navigate — carrying whatever the destination needs in order to be built.
///
/// It is a transient action payload, never stored: the navigation reducer turns it into the `StackEntry`
/// that goes on the stack. Keeping the ask separate from the screen is what lets Home dispatch tacitly
/// (`dispatch: .action(\.navigation.push.editor)`) — the `ModelDocument` it already carries flows
/// straight through, with no reducer reaching into a sibling's state to seed it.
@Prisms
public enum NavigationRequest: Sendable, Equatable {
    case editor(ModelDocument)
    case calculator(ModelDocument)
}
