import AppCore
import AppDomain
import SwiftRex
import SwiftUI

@main
struct BiokineticsDosimetryApp: SwiftUI.App {
    private let store = Store.app(world: .real)

    var body: some Scene {
        AppRoute.scene(store: store)
    }
}
