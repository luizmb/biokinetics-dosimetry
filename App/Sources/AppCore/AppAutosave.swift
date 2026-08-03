import AppDomain
import CoreFP
import CoreFPOperators
import FP
import SwiftRex
import SwiftRexArchitecture

// MARK: - Autosave

/// Effect-registry keys owned by AppCore. Module-private so no feature can collide with them.
private enum EffectID: Hashable, Sendable {
    case autosaveEditor
}

/// How long the editor must be quiet before its document is written.
///
/// `World.saveDocument` is a synchronous `JSONEncoder` + atomic file write, so writing per keystroke or
/// per drag frame is not affordable. Coalescing collapses a burst into one write; the cost of the
/// window is that force-quitting inside it loses at most that window's edits.
private let autosaveQuietPeriod: Duration = .milliseconds(400)

/// Persists the edited document on **every** change, debounced.
///
/// The editor has no Save button and never had one: before this, the only write happened when the user
/// navigated back, so force-quitting mid-edit lost the work entirely. Saving on change removes that
/// class of loss without adding an affordance the user has to remember to use.
///
/// It works in two hops, and the indirection is load-bearing. An editor action only schedules a
/// **tick**; the tick is what reads the document. `PostReducerContext.liveState` is main-actor isolated
/// and so cannot be read from the synchronous `produce` closure, but a tick arrives as its own dispatch,
/// where `stateBefore` *is* the post-edit state. The debounce therefore sits between the edit and the
/// read, which is the right way round: the document is sampled once the user has stopped, so a burst
/// costs one read and one write rather than one per keystroke.
func autosaveEditedDocumentBehavior() -> Behavior<AppAction, AppState, World> {
    scheduleAutosaveTick() <> writeOnAutosaveTick()
}

/// Any editor action restarts the quiet period. Deliberately unconditional: classifying which of the
/// editor's ~60 actions can touch the document would be a second thing to keep in step with the editor.
/// The tick is free, and the tick itself decides whether there is anything to write.
private func scheduleAutosaveTick() -> Behavior<AppAction, AppState, World> {
    .handle { action, _ in
        guard AppAction.prism.editor.preview(action) != nil else { return .doNothing }
        return .produce { _ in
            .just(.autosaveEditor)
                .scheduling(.debounce(id: EffectID.autosaveEditor, delay: autosaveQuietPeriod))
        }
    }
}

/// Writes the edited document, but only if it differs from the copy Home already holds.
///
/// Home's list *is* the record of what is on disk — `.saveDocument` updates it in the same reduce that
/// schedules the write — so comparing against it is an exact "are there unsaved changes?" test, with no
/// extra bookkeeping state to drift. That makes panning the canvas or toggling a panel free: they tick,
/// find the document unchanged, and write nothing.
private func writeOnAutosaveTick() -> Behavior<AppAction, AppState, World> {
    .handle { action, context in
        guard case .autosaveEditor = action,
              let state = context.stateBefore,
              let edited = AppScopes.editor.state.preview(state)?.document,
              storedDocument(id: edited.id, in: state) != edited
        else { return .doNothing }

        return .produce { _ in .just(.home(.saveDocument(edited))) }
    }
}

/// The copy of `id` in Home's list — the last value that was persisted, or `nil` if it was never there.
private func storedDocument(id: ModelDocument.ID, in state: AppState) -> ModelDocument? {
    let zoom = Loading<[ModelDocument], DecodingError>.prism.loaded >>> [ModelDocument].ix(id: id)
    return zoom.preview(state.home.documents)
}
