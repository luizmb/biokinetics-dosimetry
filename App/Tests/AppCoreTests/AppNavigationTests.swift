@testable import AppCore
import AppDomain
import CalculatorFeature
import CoreFP
import EditorFeature
import Foundation
import HomeFeature
import Observation
import SwiftRex
import SwiftRexArchitecture
import SwiftRexSwiftUI
import SwiftRexTesting
import Testing

// MARK: - Helpers

@MainActor
private func store(initial: AppState = AppState()) -> TestStore<AppAction, AppState, World> {
    TestStore(
        initial: initial,
        behavior: navigationBehavior(),
        environment: .matrixFakeAll,
        exhaustive: false
    )
}

/// A one-shot flag settable from the `@Sendable` `onChange` callback.
/// `@unchecked Sendable` is sound here: every access to `value` is guarded by `lock`.
private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

// MARK: - Tests
//
// There is no "a route always has its state" invariant test here, and that is the point: a screen's
// state lives *in* the `path` element, so a route without its state cannot be constructed. The
// previous design needed a test to police that; this one makes it a type error.

@Suite("Navigation: the stack is the state")
@MainActor
struct AppNavigationTests {

    @Test func startsAtTheRootWithAnEmptyStack() {
        #expect(AppState().path.isEmpty)
        #expect(AppState().routes.isEmpty)
    }

    /// Pushing appends a screen that is already complete — there is no second step that could be missed.
    @Test func pushAppendsAFullyBuiltScreen() {
        let s = store()
        s.dispatch(AppAction.navigation(.push(.editor(.validation)))) { state in
            state.path = [.editor(EditorFeature.State(document: .validation))]
        }
        #expect(s.state.routes == [AppRoute.editor])
        #expect(AppScopes.editor.state.preview(s.state)?.document == .validation)
    }

    /// The document rides along with the push, and the calculator seeds its series from it — so the
    /// screen can never exist without the data it is about to plot.
    @Test func pushCarriesEverythingTheScreenNeeds() {
        let s = store()
        s.dispatch(AppAction.navigation(.push(.calculator(.iodo131)))) { state in
            state.path = [.calculator(CalculatorFeature.State(document: .iodo131))]
        }
        let seeded = AppScopes.calculator.state.preview(s.state)?.visibleSeriesIds
        #expect(seeded == Set(ModelDocument.iodo131.model.compartments.filter(\.follow).map(\.id)))
        #expect(seeded?.isEmpty == false)
    }

    /// Popping removes the element — the screen's data goes with it, because it *is* the element.
    @Test func popRemovesTheScreenAndItsData() {
        let s = store()
        s.dispatch(AppAction.navigation(.push(.editor(.validation)))) { state in
            state.path = [.editor(EditorFeature.State(document: .validation))]
        }
        s.dispatch(AppAction.navigation(.pop)) { state in
            state.path = []
        }
        #expect(AppScopes.editor.state.preview(s.state) == nil)
    }

    /// Back button and back-swipe both arrive as `setPath`; folding to the longest matching prefix is
    /// total, so an unexpected path truncates rather than leaving the stack disagreeing with the screen.
    @Test func interactiveSetPathTruncatesToTheLongestMatchingPrefix() {
        let s = store()
        s.dispatch(AppAction.navigation(.push(.editor(.validation)))) { state in
            state.path = [.editor(EditorFeature.State(document: .validation))]
        }
        s.dispatch(AppAction.navigation(.push(.calculator(.iodo131)))) { state in
            state.path.append(.calculator(CalculatorFeature.State(document: .iodo131)))
        }
        #expect(s.state.routes == [AppRoute.editor, .calculator])

        s.dispatch(AppAction.navigation(.setPath([.editor]))) { state in
            state.path.removeLast()
        }
        #expect(AppScopes.calculator.state.preview(s.state) == nil)
        #expect(AppScopes.editor.state.preview(s.state) != nil)
    }

    @Test func popToRootEmptiesTheStack() {
        let s = store()
        s.dispatch(AppAction.navigation(.push(.editor(.validation)))) { state in
            state.path = [.editor(EditorFeature.State(document: .validation))]
        }
        s.dispatch(AppAction.navigation(.popToRoot)) { state in
            state.path = []
        }
        #expect(s.state == AppState())
    }

    /// Re-entering a screen builds a new one, so last visit's edits cannot flash on screen. The old
    /// design kept one long-lived slice per feature and had to hand-clear it on the way in.
    @Test func reenteringAScreenBuildsItAfresh() {
        var stale = EditorFeature.State(document: .iodo131)
        stale.selectedCompartmentId = "plasma"
        stale.canvasScale = 3.0
        var initial = AppState()
        initial.path = [.editor(stale)]
        let s = store(initial: initial)

        s.dispatch(AppAction.navigation(.pop)) { state in
            state.path = []
        }
        s.dispatch(AppAction.navigation(.push(.editor(.validation)))) { state in
            state.path = [.editor(EditorFeature.State(document: .validation))]
        }

        #expect(AppScopes.editor.state.preview(s.state)?.document == .validation)
        #expect(AppScopes.editor.state.preview(s.state)?.selectedCompartmentId == nil)
        #expect(AppScopes.editor.state.preview(s.state)?.canvasScale == 1.0)
    }

    /// The calculator's stale results were cleared by hand in the old bridge. Now they cannot survive,
    /// because the screen the results belonged to no longer exists.
    @Test func reenteringTheCalculatorCannotShowThePreviousRunsResults() {
        var stale = CalculatorFeature.State(document: .iodo131)
        stale.results = [[1, 2, 3]]
        stale.error = "previous failure"
        var initial = AppState()
        initial.path = [.calculator(stale)]
        let s = store(initial: initial)

        s.dispatch(AppAction.navigation(.pop)) { state in
            state.path = []
        }
        s.dispatch(AppAction.navigation(.push(.calculator(.validation)))) { state in
            state.path = [.calculator(CalculatorFeature.State(document: .validation))]
        }

        #expect(AppScopes.calculator.state.preview(s.state)?.results == nil)
        #expect(AppScopes.calculator.state.preview(s.state)?.error == nil)
    }

    @Test func popOnAnEmptyStackIsANoOp() {
        let s = store()
        s.dispatch(AppAction.navigation(.pop)) { _ in }
        #expect(s.state.path.isEmpty)
    }

    /// The scope's affine lane reads and writes the same `path` element, in place — a write lands on the
    /// screen it read from rather than on a copy.
    @Test func theAffineScopeWritesBackIntoTheElementItRead() {
        var state = AppState()
        state.path = [.editor(EditorFeature.State(document: .validation))]

        AppScopes.editor.state.modify(&state) { $0.selectedCompartmentId = "edited" }

        #expect(state.path.count == 1)
        #expect(AppScopes.editor.state.preview(state)?.selectedCompartmentId == "edited")
    }

    /// Writing a screen that is not on the stack is a no-op — the affine lane has nothing to focus, so a
    /// child behavior cannot conjure a screen navigation never pushed.
    @Test func writingAScreenThatIsNotOnTheStackChangesNothing() {
        var state = AppState()
        AppScopes.calculator.state.modify(&state) { $0.finalDay = 99 }
        #expect(state == AppState())
    }

    /// The bug that made every push a silent no-op on screen.
    ///
    /// `Store` is a plain `final class` and `StoreType.state` an ordinary protocol requirement, so a view
    /// body reading `store.state` registers **no** observation dependency: the reducer appended the
    /// route, the state was correct, and `NavigationStack` was simply never asked to re-render. Routing
    /// the root through `AppFeature`'s `ViewStore` — the same one every other screen gets — is what fixes
    /// it. `withObservationTracking` is precisely the mechanism SwiftUI uses to decide.
    @Test func theRootPathIsObservableSoAPushActuallyRerendersTheStack() async {
        let store = Store(initial: AppState(), behavior: navigationBehavior(), environment: World.matrixFakeAll)
        let viewStore = ViewStore(store)

        let invalidated = Flag()
        withObservationTracking {
            _ = viewStore.state.routes
        } onChange: {
            invalidated.set()
        }

        store.dispatch(AppAction.navigation(.push(.editor(.validation))))
        await Task.yield()

        #expect(invalidated.isSet, "SwiftUI would never re-render the NavigationStack, so no push would appear")
        #expect(viewStore.state.routes == [AppRoute.editor])
    }
}
