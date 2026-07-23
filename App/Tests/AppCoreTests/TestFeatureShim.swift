// Local shim for the retired SwiftRex `TestFeature<F>` — builds the feature's view over an
// inert store (identity behavior) for snapshot/view tests.
import SwiftRex
import SwiftRexArchitecture
import SwiftUI

struct TestFeature<F: Feature> {
    let view: F.Body

    @MainActor init(initial: F.State, environment: F.Environment) {
        let store = Store(initial: initial, behavior: Behavior<F.Action, F.State, F.Environment>.identity, environment: environment)
        view = F.view(store: store, environment: environment)
    }

    func ignoringActions(_ body: () async -> Void) async { await body() }
}
