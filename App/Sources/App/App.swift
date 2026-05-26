import AppCore
import SwiftRex
import SwiftUI

@main
struct BiokineticsDosimetryApp: SwiftUI.App {
    @State private var store = Store<AppAction, AppState, World>.app

    var body: some Scene {
        WindowGroup {
            store.rootView
        }
    }
}
