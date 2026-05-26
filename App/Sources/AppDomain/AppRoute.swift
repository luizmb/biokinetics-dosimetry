/// Every screen that can be pushed onto the navigation stack.
///
/// Each case carries the `ModelDocument` snapshot that was current when the
/// user tapped "Edit" or "Calculate" on the Home screen. The editor and
/// calculator features are initialised from this snapshot; mutations are
/// surfaced back to the home document list via the save action.
public enum AppRoute: Hashable, Sendable {
    case home
    case editor
    case calculator
}
