import AppDomain
import Domain
import EditorFeature
import Foundation
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
        initial: EditorFeature.State = EditorFeature.initialState(with: ())
    ) -> TestStore<EditorFeature.Action, EditorFeature.State, EditorFeature.Environment> {
        TestStore(initial: initial, behavior: EditorFeature.behavior(), environment: EditorFeature.Environment.test)
    }

    private func loaded(_ doc: ModelDocument = .validation) -> EditorFeature.State {
        var s = EditorFeature.initialState(with: ())
        s.document = doc
        return s
    }

    // MARK: - Typed numbers

    @Test func typedNumberKeepsTheTextAndUpdatesTheValueThroughTheParser() async {
        let initial = loaded()
        let id = initial.document.model.compartments[0].id
        let s = store(initial: initial)

        s.dispatch(.typeNumber(.fraction(compartment: id), "0.25")) { _ in }
        await s.runEffects()
        s.receive(EditorFeature.Action.prism.numberDrafted) { _, state in
            state.numberDrafts[.fraction(compartment: id)] = "0.25"
        }
        _ = s.receive(EditorFeature.Action.prism.updateCompartmentFraction) { _, state in
            state = s.state
        }
        #expect(s.state.document.model.compartments[0].fraction == 0.25)

        s.dispatch(.endNumberEditing) { $0.numberDrafts = [:] }
    }

    @Test func textThatIsNotANumberYetIsKeptAndChangesNothing() async {
        let initial = loaded()
        let id = initial.document.model.compartments[0].id
        let before = initial.document.model.compartments[0].fraction
        let s = store(initial: initial)

        s.dispatch(.typeNumber(.fraction(compartment: id), "-")) { _ in }
        await s.runEffects()
        s.receive(EditorFeature.Action.prism.numberDrafted) { _, state in
            state.numberDrafts[.fraction(compartment: id)] = "-"
        }
        #expect(s.state.document.model.compartments[0].fraction == before)
    }

    /// A field that works in hours takes typed rates in h⁻¹ and stores them in day⁻¹.
    @Test func typedRateIsTakenInTheFieldsUnit() async {
        var document = ModelDocument.validation
        document.field = .pharmacology
        let s = store(initial: loaded(document))

        s.dispatch(.typeNumber(.rate(link: 1), "2")) { _ in }
        await s.runEffects()
        s.receive(EditorFeature.Action.prism.numberDrafted) { _, state in
            state.numberDrafts[.rate(link: 1)] = "2"
        }
        _ = s.receive(EditorFeature.Action.prism.updateLinkRate) { _, state in
            state = s.state
        }
        #expect(s.state.document.model.connections[1].rate == 48)
    }

    /// And half-lives in hours, stored in days.
    @Test func typedHalfLifeIsTakenInTheFieldsUnit() async {
        var document = ModelDocument.validation
        document.field = .pharmacology
        let id = document.model.nuclides[0].id
        let s = store(initial: loaded(document))

        s.dispatch(.typeNumber(.halfLife(nuclide: id), "12")) { _ in }
        await s.runEffects()
        s.receive(EditorFeature.Action.prism.numberDrafted) { _, state in
            state.numberDrafts[.halfLife(nuclide: id)] = "12"
        }
        _ = s.receive(EditorFeature.Action.prism.updateNuclideHalfLife) { _, state in
            state = s.state
        }
        #expect(s.state.document.model.nuclides[0].halfLife == 0.5)
    }

    /// The projection shows the stored days in the field's hours.
    @Test func numbersAreShownInTheFieldsUnit() {
        var document = ModelDocument.validation
        document.field = .pharmacology
        let env = EditorFeature.Environment.test
        let vs = EditorFeature.mapState(env)(loaded(document))
        let link = document.model.connections[1]
        #expect(vs.links[1].rateText == env.formatScientific(link.rate / 24, 2))
        #expect(vs.nuclides[0].halfLifeInputText == env.formatDouble(document.model.nuclides[0].halfLife * 24, 4))
        #expect(vs.units.time == .hours)
    }

    // MARK: - Initial state

    @Test func initialState() {
        let s = EditorFeature.initialState(with: ())
        #expect(s.selectedCompartmentId == nil)
        #expect(s.selectedLinkIndex == nil)
        #expect(s.inspectorTab == .details)
        #expect(s.isLeftPanelVisible == true)
        #expect(s.isRightPanelVisible == true)
        #expect(s.showKValues == false)
        #expect(s.modelTab == .document)
        #expect(s.transferDraft == nil)
        #expect(s.canvasScale == 1.0)
    }

    // MARK: - .load

    @Test func loadSetsDocumentAndResetsDerivedState() {
        var initial = loaded()
        initial.selectedCompartmentId = "A"
        initial.selectedLinkIndex = 0
        initial.transferDraft = EditorFeature.TransferDraft(from: "A")
        initial.canvasOffset = EditorFeature.CanvasPoint(x: 100, y: 200)
        initial.canvasScale = 2.0

        store(initial: initial).dispatch(.load(.iodo131)) { state in
            state.document = .iodo131
            state.selectedCompartmentId = nil
            state.selectedLinkIndex = nil
            state.transferDraft = nil
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
        var initial = EditorFeature.initialState(with: ())
        initial.inspectorTab = .relationships
        store(initial: initial).dispatch(.setInspectorTab(.details)) { $0.inspectorTab = .details }
    }

    // MARK: - Compartment mutations

    @Test func updateCompartmentNameChangesNameOnly() {
        let initial = loaded()
        store(initial: initial).dispatch(.updateCompartmentName(id: "A", name: "Alpha")) { state in
            state.document.model = state.document.model.updatingCompartment(id: "A") {
                $0.with(name: "Alpha")
            }
        }
    }

    @Test func updateCompartmentFollowTogglesFollow() {
        let initial = loaded()
        // "A" starts with follow = true in validation
        store(initial: initial).dispatch(.updateCompartmentFollow(id: "A", value: false)) { state in
            state.document.model = state.document.model.updatingCompartment(id: "A") {
                $0.with(follow: false)
            }
        }
    }

    @Test func updateCompartmentDispose() {
        let initial = loaded()
        store(initial: initial).dispatch(.updateCompartmentDispose(id: "C", value: true)) { state in
            state.document.model = state.document.model.updatingCompartment(id: "C") {
                $0.with(dispose: true)
            }
        }
    }

    @Test func updateCompartmentIntakeSetsIntakeAndFraction() {
        let initial = loaded()
        // Enabling intake redistributes fractions equally among all intake compartments.
        // Validation doc has A already intake; enabling B gives both 0.5.
        store(initial: initial).dispatch(.updateCompartmentIntake(id: "B", value: true)) { state in
            state.document.model = state.document.model
                .updatingCompartment(id: "A") { $0.with(fraction: 0.5) }
                .updatingCompartment(id: "B") { $0.with(intake: true).with(fraction: 0.5) }
        }
    }

    @Test func updateCompartmentIntakeClearsFractionOnDisable() {
        var initial = loaded()
        // Disabling intake resets fraction to 0.
        initial.document.model = initial.document.model.updatingCompartment(id: "A") {
            $0.with(intake: true).with(fraction: 1.0)
        }
        store(initial: initial).dispatch(.updateCompartmentIntake(id: "A", value: false)) { state in
            state.document.model = state.document.model.updatingCompartment(id: "A") {
                $0.with(intake: false).with(fraction: 0)
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
            state.document.model = state.document.model.with(
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
            state.document.model = state.document.model.with(
                compartments: state.document.model.compartments.filter { $0.id != "C" },
                connections: state.document.model.connections.filter { $0.from != "C" && $0.to != "C" }
            )
            state.document.visuals.removeValue(forKey: "C")
            // selectedCompartmentId stays "A"
        }
    }

    // MARK: - Editing

    @Test func editCompartmentPicksItAndBringsUpTheInspector() {
        var initial = loaded()
        initial.selectedLinkIndex = 1
        initial.transferDraft = EditorFeature.TransferDraft(from: "A")
        store(initial: initial).dispatch(.editCompartment("B")) { state in
            state.selectedCompartmentId = "B"
            state.selectedLinkIndex = nil
            state.transferDraft = nil
            state.overlayPanel = .inspector
        }
    }

    @Test func editLinkPicksItAndBringsUpTheInspector() {
        var initial = loaded()
        initial.selectedCompartmentId = "A"
        store(initial: initial).dispatch(.editLink(2)) { state in
            state.selectedLinkIndex = 2
            state.selectedCompartmentId = nil
            state.overlayPanel = .inspector
        }
    }

    @Test func editingOnAPadOpensTheInspectorBesideTheCanvas() {
        var initial = loaded()
        initial.traits = Self.pad
        initial.isRightPanelVisible = false
        store(initial: initial).dispatch(.editCompartment("A")) { state in
            state.selectedCompartmentId = "A"
            state.isRightPanelVisible = true
        }
    }

    @Test func updateCompartmentTintRecolorsIt() {
        store(initial: loaded()).dispatch(.updateCompartmentTint(id: "A", tint: .violet)) { state in
            state.document.visuals["A"]?.tint = .violet
        }
    }

    // MARK: - Making a transfer

    @Test func beginTransferOpensTheDraftInTheInspector() {
        store(initial: loaded()).dispatch(.beginTransfer(from: "A", to: nil)) { state in
            state.transferDraft = EditorFeature.TransferDraft(from: "A")
            state.overlayPanel = .inspector
        }
    }

    @Test func choosingTheEndsFillsTheDraft() {
        var initial = loaded()
        initial.transferDraft = EditorFeature.TransferDraft()
        let s = store(initial: initial)
        s.dispatch(.setTransferFrom("A")) { $0.transferDraft?.from = "A" }
        s.dispatch(.setTransferTo("C")) { $0.transferDraft?.to = "C" }
    }

    @Test func createTransferAddsItAndEditsIt() {
        // validation: A→B(0), B→C(1), C→B(2)
        var initial = loaded()
        initial.transferDraft = EditorFeature.TransferDraft(from: "A", to: "C")
        initial.inspectorTab = .relationships
        let newConn = CompartmentConnection(from: "A", to: "C", rate: 0.1)
        store(initial: initial).dispatch(.createTransfer) { state in
            state.document.model = state.document.model.with(
                connections: state.document.model.connections + [newConn]
            )
            state.selectedLinkIndex = 3
            state.selectedCompartmentId = nil
            state.transferDraft = nil
            state.inspectorTab = .details
        }
    }

    @Test func createTransferNeedsTwoDifferentEnds() {
        var initial = loaded()
        initial.transferDraft = EditorFeature.TransferDraft(from: "A", to: "A")
        store(initial: initial).dispatch(.createTransfer)
        var half = loaded()
        half.transferDraft = EditorFeature.TransferDraft(from: "A")
        store(initial: half).dispatch(.createTransfer)
    }

    @Test func cancelTransferDropsTheDraft() {
        var initial = loaded()
        initial.transferDraft = EditorFeature.TransferDraft(from: "A")
        store(initial: initial).dispatch(.cancelTransfer) { $0.transferDraft = nil }
    }

    @Test func deletingACompartmentTakesItOutOfTheDraft() {
        var initial = loaded()
        initial.transferDraft = EditorFeature.TransferDraft(from: "A", to: "C")
        store(initial: initial).dispatch(.deleteCompartment(id: "A")) { state in
            state.document.model = state.document.model.with(
                compartments: state.document.model.compartments.filter { $0.id != "A" },
                connections: state.document.model.connections.filter { $0.from != "A" && $0.to != "A" }
            )
            state.document.visuals.removeValue(forKey: "A")
            state.transferDraft?.from = nil
        }
    }

    @Test func setModelTabSwitchesThePage() {
        store().dispatch(.setModelTab(.contents)) { $0.modelTab = .contents }
    }

    // MARK: - Link mutations

    @Test func updateLinkRateChangesRate() {
        // validation connection[1]: B→C rate=0.2
        let initial = loaded()
        store(initial: initial).dispatch(.updateLinkRate(index: 1, rate: 0.99)) { state in
            let old = state.document.model.connections[1]
            var conns = state.document.model.connections
            conns[1] = CompartmentConnection(from: old.from, to: old.to, rate: 0.99)
            state.document.model = state.document.model.with(connections: conns)
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
            state.document.model = state.document.model.with(connections: conns)
            state.selectedLinkIndex = nil   // Was 0, matches deleted index
        }
    }

    @Test func deleteLinkDoesNotClearSelectionWhenIndexDiffers() {
        var initial = loaded()
        initial.selectedLinkIndex = 2
        store(initial: initial).dispatch(.deleteLink(index: 0)) { state in
            var conns = state.document.model.connections
            conns.remove(at: 0)
            state.document.model = state.document.model.with(connections: conns)
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

    // MARK: - Panels

    private static let pad = DeviceTraits(isDark: false, isCompactWidth: false, isCompactHeight: false)
    private static let phoneOnItsSide = DeviceTraits(isDark: false, isCompactWidth: false, isCompactHeight: true)

    @Test func layoutFollowsTheTraits() {
        #expect(EditorFeature.EditorLayout(.initial) == .sheets)
        #expect(EditorFeature.EditorLayout(Self.pad) == .docked)
        #expect(EditorFeature.EditorLayout(Self.phoneOnItsSide) == .floating)
    }

    @Test func dockedPanelsOpenAndCloseOnTheirOwn() {
        var initial = EditorFeature.initialState(with: ())
        initial.traits = Self.pad
        let s = store(initial: initial)
        s.dispatch(.setPanel(.modelList, isOpen: false)) { $0.isLeftPanelVisible = false }
        s.dispatch(.setPanel(.inspector, isOpen: false)) { $0.isRightPanelVisible = false }
        s.dispatch(.setPanel(.modelList, isOpen: true)) { $0.isLeftPanelVisible = true }
        #expect(s.state.isOpen(.modelList))
        #expect(!s.state.isOpen(.inspector))
    }

    @Test func overThePhoneOnePanelAtATime() {
        // Nothing is over the canvas when the editor opens, whatever a pad left behind.
        let s = store()
        #expect(!s.state.isOpen(.modelList))
        #expect(!s.state.isOpen(.inspector))
        s.dispatch(.setPanel(.modelList, isOpen: true)) { $0.overlayPanel = .modelList }
        s.dispatch(.setPanel(.inspector, isOpen: true)) { $0.overlayPanel = .inspector }
        // Closing one that isn't up leaves the one that is.
        s.dispatch(.setPanel(.modelList, isOpen: false))
        s.dispatch(.setPanel(.inspector, isOpen: false)) { $0.overlayPanel = nil }
    }

    @Test func pickingOverThePhoneOnlyPicks() {
        var initial = loaded()
        initial.traits = Self.phoneOnItsSide
        store(initial: initial).dispatch(.selectCompartment("A")) { $0.selectedCompartmentId = "A" }
    }

    @Test func pickingOnAPadLeavesThePanelsAlone() {
        var initial = loaded()
        initial.traits = Self.pad
        initial.isRightPanelVisible = false
        store(initial: initial).dispatch(.selectCompartment("A")) { $0.selectedCompartmentId = "A" }
    }

    @Test func toggleKValuesShowsThem() {
        store().dispatch(.toggleKValues) { $0.showKValues = true }
    }
}

// MARK: - mapState tests

@Suite("EditorFeature mapState")
@MainActor
struct EditorFeatureMapStateTests {

    @Test func compartmentRowsReflectDocumentCompartments() {
        var state = EditorFeature.initialState(with: ())
        state.document = .validation
        let vs = EditorFeature.mapState(EditorFeature.Environment.test)(state)
        #expect(vs.compartments.count == 3)
        #expect(vs.compartments.map(\.id) == ["A", "B", "C"])
    }

    @Test func selectedCompartmentMarkedInRows() {
        var state = EditorFeature.initialState(with: ())
        state.document = .validation
        state.selectedCompartmentId = "B"
        let vs = EditorFeature.mapState(EditorFeature.Environment.test)(state)
        #expect(vs.compartments.first { $0.id == "B" }?.isSelected == true)
        #expect(vs.compartments.filter { $0.isSelected }.count == 1)
    }

    @Test func linkRowsReflectDocumentConnections() {
        var state = EditorFeature.initialState(with: ())
        state.document = .validation  // A→B, B→C, C→B
        let vs = EditorFeature.mapState(EditorFeature.Environment.test)(state)
        #expect(vs.links.count == 3)
        #expect(vs.links[0].fromId == "A")
        #expect(vs.links[0].toId == "B")
    }

    @Test func canvasTransformForwardedToViewState() {
        var state = EditorFeature.initialState(with: ())
        state.canvasOffset = EditorFeature.CanvasPoint(x: 42, y: -10)
        state.canvasScale = 1.8
        let vs = EditorFeature.mapState(EditorFeature.Environment.test)(state)
        #expect(vs.canvasOffsetX == 42)
        #expect(vs.canvasOffsetY == -10)
        #expect(vs.canvasScale == 1.8)
    }

    @Test func nucleiRowsReflectModelNuclides() {
        var state = EditorFeature.initialState(with: ())
        state.document = .validation  // has Nuclide("val", halfLife: 5.0)
        let vs = EditorFeature.mapState(EditorFeature.Environment.test)(state)
        #expect(vs.nuclides.count == 1)
        #expect(vs.nuclides[0].id == "val")
        #expect(vs.nuclides[0].halfLife == 5.0)
        #expect(vs.nuclides[0].compartmentCount == 3)  // A, B, C all assigned to "val"
        #expect(vs.nuclides[0].canDelete == false)  // only one nuclide
    }

    @Test func compartmentRowCarriesNuclideId() {
        var state = EditorFeature.initialState(with: ())
        state.document = .validation
        let vs = EditorFeature.mapState(EditorFeature.Environment.test)(state)
        #expect(vs.compartments.allSatisfy { $0.nuclideId == "val" })
    }
}

// MARK: - Nuclide management behavior tests

@Suite("EditorFeature Nuclide Management")
@MainActor
struct EditorFeatureNuclideTests {

    private func store(
        initial: EditorFeature.State = EditorFeature.initialState(with: ())
    ) -> TestStore<EditorFeature.Action, EditorFeature.State, EditorFeature.Environment> {
        TestStore(initial: initial, behavior: EditorFeature.behavior(), environment: EditorFeature.Environment.test)
    }

    private func loaded(_ doc: ModelDocument = .validation) -> EditorFeature.State {
        var s = EditorFeature.initialState(with: ())
        s.document = doc
        return s
    }

    // MARK: - addNuclide

    @Test func addNuclideAppendsNewNuclide() async {
        // .addNuclide only produces an effect (it draws the new nuclide's id from the
        // environment) — the actual mutation lands via the .addNuclideWithId it emits, so
        // this needs runEffects()/receive() like CalculatorFeatureTests' effect-driven
        // cases, not a bare dispatch(_:source:) (which never runs pending effects).
        let initial = loaded()
        let s = store(initial: initial)
        s.dispatch(.addNuclide) { _ in }
        await s.runEffects()
        s.receive(EditorFeature.Action.prism.addNuclideWithId) { new, state in
            // Name comes from field lingo; .validation fixture uses .generic → "New Substance"
            #expect(new.1 == "New \(state.document.field.lingo.substanceName)")
            state.document.model = state.document.model.with(
                nuclides: state.document.model.nuclides + [
                    Nuclide(id: new.0, name: new.1, halfLife: 0)
                ]
            )
        }
    }

    // MARK: - updateNuclideName

    @Test func updateNuclideNameChangesName() {
        let initial = loaded()
        store(initial: initial).dispatch(.updateNuclideName(id: "val", name: "Cs-137")) { state in
            state.document.model = state.document.model.with(
                nuclides: state.document.model.nuclides.map {
                    $0.id == "val" ? Nuclide(id: $0.id, name: "Cs-137", halfLife: $0.halfLife) : $0
                }
            )
        }
    }

    // MARK: - updateNuclideHalfLife

    @Test func updateNuclideHalfLifeSetsValue() {
        let initial = loaded()
        store(initial: initial).dispatch(.updateNuclideHalfLife(id: "val", halfLife: 30.17)) { state in
            state.document.model = state.document.model.with(
                nuclides: state.document.model.nuclides.map {
                    $0.id == "val" ? Nuclide(id: $0.id, name: $0.name, halfLife: 30.17) : $0
                }
            )
        }
    }

    @Test func updateNuclideHalfLifeClampsNegativeToZero() {
        let initial = loaded()
        store(initial: initial).dispatch(.updateNuclideHalfLife(id: "val", halfLife: -5)) { state in
            state.document.model = state.document.model.with(
                nuclides: state.document.model.nuclides.map {
                    $0.id == "val" ? Nuclide(id: $0.id, name: $0.name, halfLife: 0) : $0
                }
            )
        }
    }

    // MARK: - deleteNuclide

    @Test func deleteNuclideWithSingleNuclideIsNoOp() {
        let initial = loaded()
        // validation has exactly one nuclide — deletion must be refused
        let before = initial
        store(initial: initial).dispatch(.deleteNuclide(id: "val")) { _ in }
        _ = before  // state unchanged
    }

    @Test func deleteNuclideReassignsCompartmentsToSurvivor() {
        // Build a two-nuclide document
        let n1 = Nuclide(id: "n1", name: "N1", halfLife: 10)
        let n2 = Nuclide(id: "n2", name: "N2", halfLife: 20)
        let comps = [
            Compartment(id: "a", nuclideId: "n1", name: "A", follow: true, intake: true, dispose: false, fraction: 1),
            Compartment(id: "b", nuclideId: "n2", name: "B", follow: true, intake: false, dispose: false, fraction: 0),
        ]
        let twoNuclideDoc = ModelDocument(id: UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000002")!, 
            name: "Two",
            model: CompartmentalModel(nuclides: [n1, n2], compartments: comps, connections: [])
        )
        var initial = EditorFeature.initialState(with: ())
        initial.document = twoNuclideDoc

        store(initial: initial).dispatch(.deleteNuclide(id: "n2")) { state in
            // n2 removed; "b" reassigned to n1
            state.document.model = CompartmentalModel(
                nuclides: [n1],
                compartments: [
                    comps[0],
                    comps[1].with(nuclideId: "n1"),
                ],
                connections: []
            )
        }
    }

    // MARK: - setCompartmentNuclide

    @Test func setCompartmentNuclideReassignsIt() {
        let n1 = Nuclide(id: "n1", name: "N1", halfLife: 10)
        let n2 = Nuclide(id: "n2", name: "N2", halfLife: 20)
        let comps = [
            Compartment(id: "a", nuclideId: "n1", name: "A", follow: true, intake: true, dispose: false, fraction: 1),
        ]
        let doc = ModelDocument(
            id: UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000003")!,
            name: "Two",
            model: CompartmentalModel(nuclides: [n1, n2], compartments: comps, connections: [])
        )
        var initial = EditorFeature.initialState(with: ())
        initial.document = doc

        store(initial: initial).dispatch(.setCompartmentNuclide(compartmentId: "a", nuclideId: "n2")) { state in
            state.document.model = state.document.model.updatingCompartment(id: "a") {
                $0.with(nuclideId: "n2")
            }
        }
    }

    @Test func setCompartmentNuclideToUnknownIdIsNoOp() {
        let initial = loaded()
        let before = initial
        store(initial: initial).dispatch(.setCompartmentNuclide(compartmentId: "A", nuclideId: "nonexistent")) { _ in }
        _ = before
    }
}

// MARK: - Snapshot tests

// SwiftUI .image(layout:) strategy is only available on iOS/tvOS simulators.
// Run snapshot tests via `xcodebuild test -destination 'platform=iOS Simulator,...'`.
#if os(iOS) || os(tvOS)
import SwiftRexArchitecture
import SwiftUI

@Suite("EditorFeature Snapshots", .enabled(if: snapshotsAreComparable))
@MainActor
struct EditorFeatureSnapshotTests {

    private static let iPhoneLayout = SwiftUISnapshotLayout.fixed(width: 390,  height: 844)
    private static let iPadLayout   = SwiftUISnapshotLayout.fixed(width: 1194, height: 834)

    private func snapBoth<F: Feature>(
        _ feature: TestFeature<F>,
        named baseName: String,
        testName: String = #function,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        await feature.ignoringActions {
                assertSnapshot(of: feature.view, as: .image(layout: Self.iPhoneLayout),
                               named: "\(baseName)-iphone", file: file, testName: testName, line: line)
                assertSnapshot(of: feature.view, as: .image(layout: Self.iPadLayout),
                               named: "\(baseName)-ipad",   file: file, testName: testName, line: line)
        }
    }

    // MARK: - Baseline states

    @Test func snapshotDefaultDocument() async {
        let feature = TestFeature<EditorFeature>(initial: EditorFeature.initialState(with: ()), environment: EditorFeature.Environment.test)
        await snapBoth(feature, named: "default-document")
    }

    @Test func snapshotValidationDocument() async {
        var initial = EditorFeature.initialState(with: ())
        initial.document = .validation
        let feature = TestFeature<EditorFeature>(initial: initial, environment: EditorFeature.Environment.test)
        await snapBoth(feature, named: "validation-document")
    }

    @Test func snapshotWithPanelsHidden() async {
        var initial = EditorFeature.initialState(with: ())
        initial.document = .validation
        initial.isLeftPanelVisible = false
        initial.isRightPanelVisible = false
        let feature = TestFeature<EditorFeature>(initial: initial, environment: EditorFeature.Environment.test)
        await snapBoth(feature, named: "panels-hidden")
    }

    @Test func snapshotLeftPanelHidden() async {
        var initial = EditorFeature.initialState(with: ())
        initial.document = .validation
        initial.isLeftPanelVisible = false
        initial.isRightPanelVisible = true
        let feature = TestFeature<EditorFeature>(initial: initial, environment: EditorFeature.Environment.test)
        await snapBoth(feature, named: "left-panel-hidden")
    }

    @Test func snapshotRightPanelHidden() async {
        var initial = EditorFeature.initialState(with: ())
        initial.document = .validation
        initial.isLeftPanelVisible = true
        initial.isRightPanelVisible = false
        let feature = TestFeature<EditorFeature>(initial: initial, environment: EditorFeature.Environment.test)
        await snapBoth(feature, named: "right-panel-hidden")
    }

    // MARK: - Inspector: compartment selection + tabs

    @Test func snapshotWithCompartmentSelected() async {
        var initial = EditorFeature.initialState(with: ())
        initial.document = .validation
        initial.selectedCompartmentId = "A"
        initial.inspectorTab = .details
        initial.isRightPanelVisible = true
        let feature = TestFeature<EditorFeature>(initial: initial, environment: EditorFeature.Environment.test)
        await snapBoth(feature, named: "compartment-selected")
    }

    @Test func snapshotCompartmentRelationshipsTab() async {
        var initial = EditorFeature.initialState(with: ())
        initial.document = .validation
        initial.selectedCompartmentId = "A"
        initial.inspectorTab = .relationships
        initial.isRightPanelVisible = true
        let feature = TestFeature<EditorFeature>(initial: initial, environment: EditorFeature.Environment.test)
        await snapBoth(feature, named: "compartment-relationships-tab")
    }

    // MARK: - Inspector: link selection + tabs

    @Test func snapshotLinkSelected() async {
        var initial = EditorFeature.initialState(with: ())
        initial.document = .validation
        initial.selectedLinkIndex = 0
        initial.inspectorTab = .details
        initial.isRightPanelVisible = true
        let feature = TestFeature<EditorFeature>(initial: initial, environment: EditorFeature.Environment.test)
        await snapBoth(feature, named: "link-selected")
    }

    @Test func snapshotLinkRelationshipsTab() async {
        var initial = EditorFeature.initialState(with: ())
        initial.document = .validation
        initial.selectedLinkIndex = 0
        initial.inspectorTab = .relationships
        initial.isRightPanelVisible = true
        let feature = TestFeature<EditorFeature>(initial: initial, environment: EditorFeature.Environment.test)
        await snapBoth(feature, named: "link-relationships-tab")
    }

    @Test func snapshotInspectorEmpty() async {
        var initial = EditorFeature.initialState(with: ())
        initial.document = .validation
        initial.isRightPanelVisible = true
        let feature = TestFeature<EditorFeature>(initial: initial, environment: EditorFeature.Environment.test)
        await snapBoth(feature, named: "inspector-empty")
    }

    // MARK: - Canvas overlays

    @Test func snapshotKValuesVisible() async {
        var initial = EditorFeature.initialState(with: ())
        initial.document = .validation
        initial.showKValues = true
        let feature = TestFeature<EditorFeature>(initial: initial, environment: EditorFeature.Environment.test)
        await snapBoth(feature, named: "k-values-visible")
    }

    @Test func snapshotNewTransfer() async {
        var initial = EditorFeature.initialState(with: ())
        initial.document = .validation
        initial.transferDraft = EditorFeature.TransferDraft(from: "A")
        initial.isRightPanelVisible = true
        let feature = TestFeature<EditorFeature>(initial: initial, environment: EditorFeature.Environment.test)
        await snapBoth(feature, named: "new-transfer")
    }

    @Test func snapshotContentsPageWithAPick() async {
        var initial = EditorFeature.initialState(with: ())
        initial.document = .validation
        initial.modelTab = .contents
        initial.selectedCompartmentId = "A"
        let feature = TestFeature<EditorFeature>(initial: initial, environment: EditorFeature.Environment.test)
        await snapBoth(feature, named: "contents-page-picked")
    }

    // MARK: - Multi-nuclide document (phase 2)

    @Test func snapshotMultiNuclideDocument() async {
        var initial = EditorFeature.initialState(with: ())
        initial.document = Self.multiNuclideDoc
        let feature = TestFeature<EditorFeature>(initial: initial, environment: EditorFeature.Environment.test)
        await snapBoth(feature, named: "multi-nuclide-document")
    }

    @Test func snapshotMultiNuclideCompartmentInspector() async {
        var initial = EditorFeature.initialState(with: ())
        initial.document = Self.multiNuclideDoc
        initial.selectedCompartmentId = "k2"
        initial.inspectorTab = .details
        initial.isRightPanelVisible = true
        let feature = TestFeature<EditorFeature>(initial: initial, environment: EditorFeature.Environment.test)
        await snapBoth(feature, named: "multi-nuclide-compartment-inspector")
    }

    // MARK: - Fixtures

    private static var multiNuclideDoc: ModelDocument {
        let n1 = Nuclide(id: "n1", name: "I-131",  halfLife: 8.02)
        let n2 = Nuclide(id: "n2", name: "Cs-137", halfLife: 30.17)
        let comps = [
            Compartment(id: "p1", nuclideId: "n1", name: "Plasma",  follow: true, intake: true,  dispose: false, fraction: 1.0),
            Compartment(id: "t1", nuclideId: "n1", name: "Thyroid", follow: true, intake: false, dispose: false, fraction: 0),
            Compartment(id: "b2", nuclideId: "n2", name: "Blood",   follow: true, intake: true,  dispose: false, fraction: 1.0),
            Compartment(id: "k2", nuclideId: "n2", name: "Kidney",  follow: true, intake: false, dispose: false, fraction: 0),
        ]
        let connections = [
            CompartmentConnection(from: "p1", to: "t1", rate: 0.866),
            CompartmentConnection(from: "b2", to: "k2", rate: 0.12),
        ]
        return ModelDocument(
            id: UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000004")!,
            name: "Multi-Nuclide",
            model: CompartmentalModel(nuclides: [n1, n2], compartments: comps, connections: connections),
            visuals: [
                "p1": CompartmentVisuals(x: 180, y: 200, tint: .steel),
                "t1": CompartmentVisuals(x: 380, y: 200, tint: .crimson),
                "b2": CompartmentVisuals(x: 180, y: 400, tint: .amber),
                "k2": CompartmentVisuals(x: 380, y: 400, tint: .forest),
            ]
        )
    }
}
#endif
