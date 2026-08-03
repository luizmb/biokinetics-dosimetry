@testable import AppCore
import AppDomain
import CalculatorFeature
import CoreFP
import CoreFPOperators
import EditorFeature
import FP
import Foundation
import HomeFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftRexTesting
import Testing

// MARK: - Helpers

/// A clock that never waits, so the autosave debounce resolves within the test.
///
/// This makes the *path* — edit → tick → write — observable. It deliberately does **not** exercise the
/// quiet period itself: with no delay there is nothing to coalesce, so "a burst of edits collapses into
/// one write" is not covered here. Covering it needs a manually-advanced clock, which neither
/// `SwiftRexTesting` nor this package currently ships.
private struct ImmediateClock: Clock, Sendable {
    struct Instant: InstantProtocol, Sendable {
        var offset: Duration = .zero

        func advanced(by duration: Duration) -> Self { Self(offset: offset + duration) }
        func duration(to other: Self) -> Duration { other.offset - offset }
        static func < (lhs: Self, rhs: Self) -> Bool { lhs.offset < rhs.offset }
    }

    var now: Instant { Instant() }
    var minimumResolution: Duration { .zero }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {}
}

/// Autosave only means anything on top of the editor's own reducer — it reads what the editor wrote.
/// Folding both is also what the app does, so these tests exercise the real composition.
@MainActor
private func store(initial: AppState) -> TestStore<AppAction, AppState, World> {
    TestStore(
        initial: initial,
        behavior: navigationBehavior()
            <> AppScopes.editor.behavior(of: EditorFeature.self)
            <> autosaveEditedDocumentBehavior(),
        environment: .matrixFakeAll,
        exhaustive: false,
        clock: { _ in ImmediateClock() }
    )
}

/// An app sitting in the editor on `document`, with Home already holding the same (i.e. saved) copy.
private func editing(_ document: ModelDocument) -> AppState {
    var state = AppState()
    state.home.documents = .loaded([document])
    state.path = [.editor(EditorFeature.State(document: document))]
    return state
}

private let savedDocument = AppAction.prism.home >>> HomeModule.Action.prism.saveDocument

// MARK: - Tests

@Suite("Autosave: the editor's work survives a force-quit")
@MainActor
struct AppAutosaveTests {

    /// The whole point: an edit reaches disk without the user asking, and without leaving the screen.
    @Test func editingTheDocumentPersistsIt() async {
        let s = store(initial: editing(.validation))

        s.dispatch(AppAction.editor(.renameDocument("Renamed"))) { state in
            AppScopes.editor.state.modify(&state) { $0.document.name = "Renamed" }
        }
        await s.runEffects()
        s.receive(AppAction.prism.autosaveEditor) { _ in }
        await s.runEffects()

        let written = s.receive(savedDocument) { _, _ in }
        #expect(written != nil, "the edit never reached Home, so it would never reach disk")
        #expect(savedDocument.preview(written ?? .appLaunch)?.name == "Renamed")
    }

    /// Every editor action ticks. Classifying which of the editor's ~60 actions can touch the document
    /// would be a second thing to keep in step with the editor; the tick is free and decides for itself.
    @Test func everyEditorActionSchedulesATick() async {
        let s = store(initial: editing(.validation))

        s.dispatch(AppAction.editor(.setCanvasTransform(offsetX: 10, offsetY: 20, scale: 2))) { state in
            AppScopes.editor.state.modify(&state) {
                $0.canvasOffset = EditorFeature.CanvasPoint(x: 10, y: 20)
                $0.canvasScale = 2
            }
        }
        await s.runEffects()

        #expect(s.receive(AppAction.prism.autosaveEditor) { _ in } != nil)
    }

    /// ...and a tick that finds nothing changed writes nothing. This is what makes an unconditional tick
    /// affordable: panning the canvas, selecting a compartment or toggling a panel all cost zero writes.
    @Test func aTickWithNoDocumentChangeWritesNothing() async {
        let s = store(initial: editing(.validation))

        s.dispatch(AppAction.autosaveEditor) { _ in }
        await s.runEffects()

        #expect(s.receivedActions.isEmpty, "an unchanged document was written to disk anyway")
    }

    /// Home's list is the record of what is on disk, so a document that is *not* in it is unsaved and
    /// must be written — a freshly imported or duplicated document, for instance.
    @Test func aDocumentHomeHasNeverSeenIsWritten() async {
        var state = AppState()
        state.home.documents = .loaded([])
        state.path = [.editor(EditorFeature.State(document: .validation))]
        let s = store(initial: state)

        s.dispatch(AppAction.autosaveEditor) { _ in }
        await s.runEffects()

        #expect(s.receive(savedDocument) { _, _ in } != nil)
    }

    /// A tick with no editor on the stack is inert — nothing to read, nothing to write.
    @Test func aTickWithNoEditorOnTheStackWritesNothing() async {
        let s = store(initial: AppState())

        s.dispatch(AppAction.autosaveEditor) { _ in }
        await s.runEffects()

        #expect(s.receivedActions.isEmpty)
    }

    /// Editing and leaving straight away — inside the quiet period — must still write.
    ///
    /// This is the hole the debounced tick leaves on its own: it reads the document off the stack when
    /// it fires, and by then the pop has taken the entry with it. Every exit is covered, because the
    /// editor has no Back button and the system chrome only ever sends `setPath`.
    @Test(arguments: [
        NavigationAction.pop,
        NavigationAction.popToRoot,
        NavigationAction.setPath([]),
    ])
    func leavingTheEditorWritesImmediately(exit: NavigationAction) async {
        let s = store(initial: editing(.validation))

        s.dispatch(AppAction.editor(.renameDocument("Renamed"))) { state in
            AppScopes.editor.state.modify(&state) { $0.document.name = "Renamed" }
        }
        // Deliberately no runEffects() for the tick — the user left before the quiet period elapsed.
        s.dispatch(AppAction.navigation(exit)) { state in
            state.path = []
        }
        await s.runEffects()

        let written = s.receive(savedDocument) { _, _ in }
        #expect(written != nil, "the edit left with the screen — this is how a force-quit loses work")
        #expect(savedDocument.preview(written ?? .appLaunch)?.name == "Renamed")
    }

    /// ...but leaving with nothing unsaved does not write. The tick and the flush both ask Home whether
    /// anything changed, so an edit that already reached disk is not written twice on the way out.
    @Test func leavingWithNothingUnsavedWritesNothing() async {
        let s = store(initial: editing(.validation))

        s.dispatch(AppAction.navigation(.pop)) { state in
            state.path = []
        }
        await s.runEffects()

        #expect(s.receivedActions.isEmpty)
    }

    /// Pushing is not leaving — nothing departs, so nothing is written.
    @Test func pushingDoesNotWrite() async {
        let s = store(initial: editing(.validation))

        s.dispatch(AppAction.navigation(.push(.calculator(.iodo131)))) { state in
            state.path.append(.calculator(CalculatorFeature.State(document: .iodo131)))
        }
        await s.runEffects()

        #expect(s.receivedActions.isEmpty)
    }
}
