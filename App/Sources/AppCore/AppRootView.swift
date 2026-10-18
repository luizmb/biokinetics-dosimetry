import AppDomain
import SwiftRex
import SwiftRexArchitecture
import SwiftRexSwiftUI
import SwiftUI
import Vitral

/// The app shell — a `NavigationStack` over the store's path.
///
/// It knows exactly two things: its ``ViewStore`` and an ``AppRouter``. No `World`, no feature types, no
/// idea how a child screen is assembled — it asks the router for a destination and renders it. The store
/// and the router are handed in at construction by ``AppFeature``, which is the only place holding the
/// `World`.
///
/// Holding the router rather than reading it from `@Environment` is deliberate: it is deterministic
/// across sheet and cover boundaries, exactly where SwiftUI's environment propagation is not.
///
/// This view owns the app's view store (`@OwnedStore`, made once from the store in `init`): a store
/// can't be read, only a view store can, and reading the path through it is what re-renders
/// `NavigationStack` when the reducer appends a route.
public struct AppRootView: View, Routable {
    @OwnedStore var viewStore: ViewStore<AppAction, AppState>
    public let router: AppRouter

    init(store: any StoreType<AppAction, AppState>, router: AppRouter) {
        _viewStore = OwnedStore(wrappedValue: store.viewStore())
        self.router = router
    }

    public var body: some View {
        NavigationStack(path: viewStore.binding(.state(\.routes).action(\.navigation.setPath))) {
            router.root(from: viewStore)
                .navigationDestination(for: AppRoute.self) { route in
                    router.destination(for: route, from: viewStore)
                }
        }
        // Buttons are clear glass under Aqua's gloss and glow; the main action keeps the accent.
        .controlFinish(.glass(.clear).sheen(.aqua(0.25)))
    }
}
