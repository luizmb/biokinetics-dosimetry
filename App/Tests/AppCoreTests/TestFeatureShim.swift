// Local shim for the retired SwiftRex `TestFeature<F>` — builds the feature's view over an
// inert store (identity behavior) for snapshot/view tests.
//
// `@MainActor` on the type, not just the initialiser: `F.Body` is a SwiftUI view built on the main
// actor, so an unisolated `ignoringActions` would be sending it — and its non-Sendable closure —
// across isolation domains. The snapshot suites are `@MainActor` themselves, so this costs nothing.
import SwiftRex
import SwiftRexArchitecture
import SwiftUI

@MainActor
struct TestFeature<F: Feature> {
    let view: F.Body

    init(initial: F.State, environment: F.Environment) {
        let store = Store(initial: initial, behavior: Behavior<F.Action, F.State, F.Environment>.identity, environment: environment)
        view = F.view(store: store, environment: environment)
    }

    func ignoringActions(_ body: () async -> Void) async { await body() }
}
