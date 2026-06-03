import AppCore
import AppDomain
import SwiftRex
import SwiftUI
import UIKit

@main
struct BiokineticsDosimetryApp: SwiftUI.App {
    private let store = Store.app(world: .real)

    init() {
        UIScrollView.appearance().alwaysBounceHorizontal = false
    }

    var body: some Scene {
        AppRoute.scene(store: store)
    }
}
