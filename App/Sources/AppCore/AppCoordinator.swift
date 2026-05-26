import SwiftRex
import SwiftUI

// MARK: - AppCoordinator

/// Owns the global `Store` and produces the root SwiftUI view.
///
/// `AppCoordinator` is deliberately thin: it creates the store once and delegates
/// all ViewModel creation to the individual feature views via `@State`.
/// No ViewModel is instantiated until the view that needs it first appears on screen.
@MainActor
public final class AppCoordinator {
    public let store: Store<AppAction, AppState, World>

    public init() {
        store = Store(
            initial: AppState(),
            behavior: NavigationFeature.behavior(),
            environment: World.live
        )
    }

    /// The root navigation view, ready to be placed in a `WindowGroup`.
    public var rootView: some View {
        AppRootView(store: store)
    }
}
