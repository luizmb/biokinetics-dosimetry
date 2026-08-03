import AppDomain
import SwiftRex
import SwiftRexArchitecture
import SwiftRexSwiftUI
import SwiftUI
import UIComponents

/// The app shell — a `NavigationStack` over the store's path.
///
/// It knows exactly two things: a ``ViewStore`` and an ``AppRouter``. No `World`, no feature types, no
/// idea how a child screen is assembled — it asks the router for a destination and renders it. Both are
/// handed in at construction by ``AppFeature``, which is the only place holding the `World`.
///
/// Holding the router rather than reading it from `@Environment` is deliberate: it is deterministic
/// across sheet and cover boundaries, exactly where SwiftUI's environment propagation is not.
///
/// The `viewStore` here is what makes navigation work at all. `Store` is a plain `final class` and
/// `StoreType.state` an ordinary protocol requirement, so a body reading a bare store registers no
/// observation dependency: the reducer would append the route, the state would be correct, and
/// `NavigationStack` would simply never be asked to re-render. `ViewStore` is `@Observable`.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public struct AppRootView: View, Routable {
    let viewStore: ViewStore<AppState, AppAction>
    public let router: AppRouter

    init(viewStore: ViewStore<AppState, AppAction>, router: AppRouter) {
        self.viewStore = viewStore
        self.router = router
    }

    public var body: some View {
        NavigationStack(
            path: viewStore.binding(.state(\.routes), dispatch: .action(\.navigation.setPath))
        ) {
            router.root()
                .navigationDestination(for: AppRoute.self) { route in
                    router.destination(for: route)
                }
        }
        .glassEnvironment()
    }
}
