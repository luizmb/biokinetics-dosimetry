import AppCore
import SwiftRex
import SwiftUI

@main
struct BiokineticsDosimetryApp: SwiftUI.App {
    let store = Store<AppAction, AppState, World>.app(environment: .live)

    var body: some Scene {
        WindowGroup {
            store.rootView
        }
    }
}
