// Local shim for the retired SwiftRex `TestFeature<F>` — builds the feature's view over an
// inert store (identity behavior) for snapshot/view tests.
//
// `@MainActor` on the type, not just the initialiser: `F.Body` is a SwiftUI view built on the main
// actor, so an unisolated `ignoringActions` would be sending it — and its non-Sendable closure —
// across isolation domains. The snapshot suites are `@MainActor` themselves, so this costs nothing.
import Foundation
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

/// Whether reference images can be compared against what this machine renders.
///
/// Snapshots are pixel comparisons, and a simulator does not rasterise identically across CPU
/// architectures. These references were recorded on an **x86_64** host; GitHub's macOS runners are
/// **arm64**, and every image differs there — text antialiasing, not layout. Loosening the
/// comparison until the two agree would weaken it everywhere, including on the machine where it can
/// be exact, so the snapshot suites simply do not run on CI.
///
/// This is a real narrowing of what CI checks, and worth being clear about: CI still compiles and
/// runs every other iOS-only test, which is the failure that actually went unnoticed for months
/// (the suites stopped compiling and nothing reported it). It does not verify rendering. Recording
/// on the same architecture CI uses is what would close that gap.
let snapshotsAreComparable = ProcessInfo.processInfo.environment["CI"] == nil
