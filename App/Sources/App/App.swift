import AppCore
import AppDomain
import SwiftRex
import SwiftUI
import UIKit

@main
struct BiokineticsDosimetryApp: SwiftUI.App {
    private let world = World.real
    private let store: MainStoreType

    init() {
        UIScrollView.appearance().alwaysBounceHorizontal = false
        store = MainStore.app(world: world)
    }

    var body: some Scene {
        WindowGroup {
            // The app is an ordinary Feature: it builds its own view, and the World stops there.
            AppFeature.view(store: store, environment: world)
        }
    }
}
