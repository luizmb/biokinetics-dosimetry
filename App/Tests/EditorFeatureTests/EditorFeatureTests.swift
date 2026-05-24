import AppDomain
import Domain
import EditorFeature
import SnapshotTesting
import SwiftRex
import SwiftRexTesting
import Testing

// MARK: - Behavior tests

/// Tests that exercise the EditorFeature state machine in isolation.
/// All actions are pure reduces (no async effects), so no `runEffects` calls are needed.
@Suite("EditorFeature Behavior")
@MainActor
struct EditorFeatureBehaviorTests {

    // MARK: - Helpers

    private func store(
        initial: EditorFeature.State = EditorFeature.initialState()
    ) -> TestStore<EditorFeature.Action, EditorFeature.State, EditorFeature.Environment> {
        TestStore(initial: initial, behavior: EditorFeature.behavior(), environment: .init())
    }

    private func loaded(_ doc: ModelDocument = .validation) -> EditorFeature.State {
        var s = EditorFeature.initialState()
        s.document = doc
        return s
    }

    // MARK: - Initial state

    @Test func initialState() {
        let s = EditorFeature.initialState()
        #expect(s.selectedCompartmentId == nil)
        #expect(s.selectedLinkIndex == nil)
        #expect(s.inspectorTab == .details)
        #expect(s.isLeftPanelVisible == true)
        #expect(s.isRightPanelVisible == true)
        #expect(s.showKValues == false)
        #expect(s.linkingState == .idle)
        #expect(s.canvasScale == 1.0)
    }

    // MARK: - .load

    @Test func loadSetsDocumentAndResetsDerivedState() {
        var initial = loaded()
        initial.selectedCompartmentId = "A"
        initial.selectedLinkIndex = 0
        initial.linkingState = .awaitingFrom
        initial.canvasOffset = EditorFeature.CanvasPoint(x: 100, y: 200)
        initial.canvasScale = 2.0

        store(initial: initial).dispatch(.load(.iodo131)) { state in
            state.document = .iodo131
            state.selectedCompartmentId = nil
            state.selectedLinkIndex = nil
            state.linkingState = .idle
            state.canvasOffset = EditorFeature.CanvasPoint(x: 0, y: 0)
            state.canvasScale = 1.0
        }
    }

    // MARK: - Selection

    @Test func selectCompartmentSetIdAndClearsLink() {
        var initial = loaded()
        initial.selectedLinkIndex = 1
        store(initial: initial).dispatch(.selectCompartment("A")) { state in
            state.selectedCompartmentId = "A"
            state.selectedLinkIndex = nil
        }
    }

    @Test func selectCompartmentNilClearsSelection() {
        var initial = loaded()
        initial.selectedCompartmentId = "A"
        store(initial: initial).dispatch(.selectCompartment(nil)) { state in
            state.selectedCompartmentId = nil
            state.selectedLinkIndex = nil
        }
    }

    @Test func selectLinkSetsIndexAndClearsCompartment() {
        var initial = loaded()
        initial.selectedCompartmentId = "A"
        store(initial: initial).dispatch(.selectLink(0)) { state in
            state.selectedLinkIndex = 0
            state.selectedCompartmentId = nil
        }
    }

    @Test func selectLinkNilClearsSelection() {
        var initial = loaded()
        initial.selectedLinkIndex = 2
        store(initial: initial).dispatch(.selectLink(nil)) { state in
            state.selectedLinkIndex = nil
            state.selectedCompartmentId = nil
        }
    }

    // MARK: - Inspector tab

    @Test func setInspectorTabToRelationships() {
        store().dispatch(.setInspectorTab(.relationships)) { $0.inspectorTab = .relationships }
    }

    @Test func setInspectorTabBackToDetails() {
        var initial = EditorFeature.initialState()
        initial.inspectorTab = .relationships
        store(initial: initial).dispatch(.setInspectorTab(.details)) { $0.inspectorTab = .details }
    }

    // MARK: - Compartment mutations

    @Test func updateCompartmentNameChangesNameOnly() {
        let initial = loaded()
        store(initial: initial).dispatch(.updateCompartmentName(id: "A", name: "Alpha")) { state in
            state.document.model = CompartmentalModel(
                compartments: state.document.model.compartments.map {
                    $0.id == "A"
                        ? Compartment(id: $0.id, name: "Alpha", follow: $0.follow,
                                      intake: $0.intake, dispose: $0.dispose, fraction: $0.fraction)
                        : $0
                },
                connections: state.document.model.connections
            )
        }
    }

    @Test func updateCompartmentFollowTogglesFollow() {
        let initial = loaded()
        // "A" starts with follow = true in validation
        store(initial: initial).dispatch(.updateCompartmentFollow(id: "A", value: false)) { state in
            state.document.model = state.document.model.updatingCompartment(id: "A") {
                Compartment(id: $0.id, name: $0.name, follow: false,
                            intake: $0.intake, dispose: $0.dispose, fraction: $0.fraction)
            }
        }
    }

    @Test func updateCompartmentDispose() {
        let initial = loaded()
        store(initial: initial).dispatch(.updateCompartmentDispose(id: "C", value: true)) { state in
            state.document.model = state.document.model.updatingCompartment(id: "C") {
                Compartment(id: $0.id, name: $0.name, follow: $0.follow,
                            intake: $0.intake, dispose: true, fraction: $0.fraction)
            }
        }
    }

    @Test func updateCompartmentIntake() {
        let initial = loaded()
        store(initial: initial).dispatch(.updateCompartmentIntake(id: "B", value: true)) { state in
            state.document.model = state.document.model.updatingCompartment(id: "B") {
                Compartment(id: $0.id, name: $0.name, follow: $0.follow,
                            intake: true, dispose: $0.dispose, fraction: $0.fraction)
            }
        }
    }

    @Test func moveCompartmentUpdatesVisuals() {
        let initial = loaded()
        // The validation doc has visuals for "A" at (280, 200)
        store(initial: initial).dispatch(.moveCompartment(id: "A", x: 100.0, y: 50.0)) { state in
            if var vis = state.document.visuals["A"] {
                vis.x = 100.0; vis.y = 50.0
                state.document.visuals["A"] = vis
            }
        }
    }

    @Test func deleteCompartmentRemovesItAndConnections() {
        // validation: A→B (0), B→C (1), C→B (2)
        // Deleting B removes all connections touching B: all three
        var initial = loaded()
        initial.selectedCompartmentId = "B"
        store(initial: initial).dispatch(.deleteCompartment(id: "B")) { state in
            state.document.model = CompartmentalModel(
                compartments: state.document.model.compartments.filter { $0.id != "B" },
                connections: []  // All connections involve B
            )
            state.document.visuals.removeValue(forKey: "B")
            state.selectedCompartmentId = nil
        }
    }

    @Test func deleteCompartmentThatIsNotSelectedLeavesSelectionUnchanged() {
        var initial = loaded()
        initial.selectedCompartmentId = "A"
        // Delete C — A→B survives; B→C and C→B removed
        store(initial: initial).dispatch(.deleteCompartment(id: "C")) { state in
            state.document.model = CompartmentalModel(
                compartments: state.document.model.compartments.filter { $0.id != "C" },
                connections: state.document.model.connections.filter { $0.from != "C" && $0.to != "C" }
            )
            state.document.visuals.removeValue(forKey: "C")
            // selectedCompartmentId stays "A"
        }
    }

    // MARK: - Linking flow

    @Test func beginLinkingSetsAwaitingFrom() {
        store().dispatch(.beginLinking) { $0.linkingState = .awaitingFrom }
    }

    @Test func linkStepFirstTapSetsAwaitingTo() {
        var initial = EditorFeature.initialState()
        initial.linkingState = .awaitingFrom
        store(initial: initial).dispatch(.linkStep("A")) { $0.linkingState = .awaitingTo(fromId: "A") }
    }

    @Test func linkStepSecondTapCreatesConnectionAndSelectsIt() {
        // validation: A→B(0), B→C(1), C→B(2)
        var initial = loaded()
        initial.linkingState = .awaitingTo(fromId: "A")
        let newConn = CompartmentConnection(from: "A", to: "C", rate: 0.1)
        store(initial: initial).dispatch(.linkStep("C")) { state in
            state.document.model = CompartmentalModel(
                compartments: state.document.model.compartments,
                connections: state.document.model.connections + [newConn]
            )
            state.selectedLinkIndex = 3      // Was 3 connections; new one is at index 3
            state.selectedCompartmentId = nil
            state.linkingState = .idle
            state.isRightPanelVisible = true
        }
    }

    @Test func linkStepSelfLoopCancelsLinkingWithoutAddingConnection() {
        var initial = loaded()
        initial.linkingState = .awaitingTo(fromId: "A")
        store(initial: initial).dispatch(.linkStep("A")) { state in
            // fromId == id → guard fires, just sets linkingState = .idle
            state.linkingState = .idle
        }
    }

    @Test func cancelLinkingResetsToIdle() {
        var initial = EditorFeature.initialState()
        initial.linkingState = .awaitingTo(fromId: "A")
        store(initial: initial).dispatch(.cancelLinking) { $0.linkingState = .idle }
    }

    // MARK: - Link mutations

    @Test func updateLinkRateChangesRate() {
        // validation connection[1]: B→C rate=0.2
        let initial = loaded()
        store(initial: initial).dispatch(.updateLinkRate(index: 1, rate: 0.99)) { state in
            let old = state.document.model.connections[1]
            var conns = state.document.model.connections
            conns[1] = CompartmentConnection(from: old.from, to: old.to, rate: 0.99)
            state.document.model = CompartmentalModel(
                compartments: state.document.model.compartments,
                connections: conns
            )
        }
    }

    @Test func updateLinkRateWithOutOfBoundsIndexDoesNothing() {
        let initial = loaded()
        let before = initial
        // Dispatch an out-of-bounds index — state must not change
        store(initial: initial).dispatch(.updateLinkRate(index: 99, rate: 0.5)) { _ in }
        // The behavior has `guard idx < count else { return }` → no mutation
        // Passing `{ _ in }` would fail if state changed; here it matches
        // because the guard prevents mutation.
        // (TestStore assertion: expected == before == after → passes)
        _ = before
    }

    @Test func deleteLinkRemovesConnectionAndClearsSelectionIfMatches() {
        // validation: A→B(0), B→C(1), C→B(2) — delete index 0
        var initial = loaded()
        initial.selectedLinkIndex = 0
        store(initial: initial).dispatch(.deleteLink(index: 0)) { state in
            var conns = state.document.model.connections
            conns.remove(at: 0)
            state.document.model = CompartmentalModel(
                compartments: state.document.model.compartments,
                connections: conns
            )
            state.selectedLinkIndex = nil   // Was 0, matches deleted index
        }
    }

    @Test func deleteLinkDoesNotClearSelectionWhenIndexDiffers() {
        var initial = loaded()
        initial.selectedLinkIndex = 2
        store(initial: initial).dispatch(.deleteLink(index: 0)) { state in
            var conns = state.document.model.connections
            conns.remove(at: 0)
            state.document.model = CompartmentalModel(
                compartments: state.document.model.compartments,
                connections: conns
            )
            // selectedLinkIndex stays 2 (different from deleted index 0)
        }
    }

    // MARK: - Canvas

    @Test func setCanvasTransformUpdatesOffsetAndScale() {
        store().dispatch(.setCanvasTransform(offsetX: 50, offsetY: -20, scale: 1.5)) { state in
            state.canvasOffset = EditorFeature.CanvasPoint(x: 50, y: -20)
            state.canvasScale = 1.5
        }
    }

    @Test func setCanvasScaleClampedToMin() {
        store().dispatch(.setCanvasTransform(offsetX: 0, offsetY: 0, scale: 0.05)) { state in
            state.canvasOffset = EditorFeature.CanvasPoint(x: 0, y: 0)
            state.canvasScale = 0.2   // clamped from 0.05 → 0.2
        }
    }

    @Test func setCanvasScaleClampedToMax() {
        store().dispatch(.setCanvasTransform(offsetX: 0, offsetY: 0, scale: 10.0)) { state in
            state.canvasOffset = EditorFeature.CanvasPoint(x: 0, y: 0)
            state.canvasScale = 5.0   // clamped from 10.0 → 5.0
        }
    }

    // MARK: - Panel toggles

    @Test func toggleLeftPanelHidesIt() {
        store().dispatch(.toggleLeftPanel) { $0.isLeftPanelVisible = false }
    }

    @Test func toggleLeftPanelTwiceRestores() {
        let s = store()
        s.dispatch(.toggleLeftPanel) { $0.isLeftPanelVisible = false }
        s.dispatch(.toggleLeftPanel) { $0.isLeftPanelVisible = true }
    }

    @Test func toggleRightPanelHidesIt() {
        store().dispatch(.toggleRightPanel) { $0.isRightPanelVisible = false }
    }

    @Test func toggleKValuesShowsThem() {
        store().dispatch(.toggleKValues) { $0.showKValues = true }
    }

    // MARK: - .save

    @Test func saveProducesNoStateChange() {
        // .save is .doNothing — no mutation, no effect
        store().dispatch(.save) { _ in }
    }
}

// MARK: - mapState tests

@Suite("EditorFeature mapState")
@MainActor
struct EditorFeatureMapStateTests {

    @Test func compartmentRowsReflectDocumentCompartments() {
        var state = EditorFeature.initialState()
        state.document = .validation
        let vs = EditorFeature.mapState(state)
        #expect(vs.compartments.count == 3)
        #expect(vs.compartments.map(\.id) == ["A", "B", "C"])
    }

    @Test func selectedCompartmentMarkedInRows() {
        var state = EditorFeature.initialState()
        state.document = .validation
        state.selectedCompartmentId = "B"
        let vs = EditorFeature.mapState(state)
        #expect(vs.compartments.first { $0.id == "B" }?.isSelected == true)
        #expect(vs.compartments.filter { $0.isSelected }.count == 1)
    }

    @Test func linkRowsReflectDocumentConnections() {
        var state = EditorFeature.initialState()
        state.document = .validation  // A→B, B→C, C→B
        let vs = EditorFeature.mapState(state)
        #expect(vs.links.count == 3)
        #expect(vs.links[0].fromId == "A")
        #expect(vs.links[0].toId == "B")
    }

    @Test func canvasTransformForwardedToViewState() {
        var state = EditorFeature.initialState()
        state.canvasOffset = EditorFeature.CanvasPoint(x: 42, y: -10)
        state.canvasScale = 1.8
        let vs = EditorFeature.mapState(state)
        #expect(vs.canvasOffsetX == 42)
        #expect(vs.canvasOffsetY == -10)
        #expect(vs.canvasScale == 1.8)
    }
}

// MARK: - Snapshot tests

// SwiftUI .image(layout:) strategy is only available on iOS/tvOS simulators.
// Run snapshot tests via `xcodebuild test -destination 'platform=iOS Simulator,...'`.
#if os(iOS) || os(tvOS)
import SwiftUI

@Suite("EditorFeature Snapshots")
@MainActor
struct EditorFeatureSnapshotTests {

    private static let snapshotLayout = SwiftUISnapshotLayout.fixed(width: 900, height: 600)

    private func snap<F: Feature>(
        _ feature: TestFeature<F>,
        named name: String,
        testName: String = #function,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async where F.Content: View {
        await feature.ignoringActions {
            assertSnapshot(
                of: feature.view,
                as: .image(layout: Self.snapshotLayout),
                named: name,
                file: file,
                testName: testName,
                line: line
            )
        }
    }

    @Test func snapshotDefaultDocument() async {
        let feature = TestFeature<EditorFeature>(environment: .init())
        await snap(feature, named: "default-document")
    }

    @Test func snapshotValidationDocument() async {
        var initial = EditorFeature.initialState()
        initial.document = .validation
        let feature = TestFeature<EditorFeature>(initial: initial, environment: .init())
        await snap(feature, named: "validation-document")
    }

    @Test func snapshotWithCompartmentSelected() async {
        var initial = EditorFeature.initialState()
        initial.document = .validation
        initial.selectedCompartmentId = "A"
        initial.isRightPanelVisible = true
        let feature = TestFeature<EditorFeature>(initial: initial, environment: .init())
        await snap(feature, named: "compartment-selected")
    }

    @Test func snapshotWithPanelsHidden() async {
        var initial = EditorFeature.initialState()
        initial.document = .validation
        initial.isLeftPanelVisible = false
        initial.isRightPanelVisible = false
        let feature = TestFeature<EditorFeature>(initial: initial, environment: .init())
        await snap(feature, named: "panels-hidden")
    }

    @Test func snapshotDuringLinking() async {
        var initial = EditorFeature.initialState()
        initial.document = .validation
        initial.linkingState = .awaitingTo(fromId: "A")
        let feature = TestFeature<EditorFeature>(initial: initial, environment: .init())
        await snap(feature, named: "linking-in-progress")
    }
}
#endif
