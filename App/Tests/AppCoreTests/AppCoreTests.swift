import AppCore
import AppDomain
import DataStructure
import Domain
import Foundation
import HomeFeature
import SnapshotTesting
import SwiftRex
import SwiftRexArchitecture
import SwiftRexTesting
import Testing

// MARK: - Behavior tests

/// Tests that exercise the HomeFeature state machine in isolation.
@Suite("HomeFeature Behavior")
@MainActor
struct HomeFeatureBehaviorTests {

    // MARK: - Helpers

    private let mockEnv = HomeModule.Environment.alwaysFails

    private func store(
        initial: HomeFeature.State = HomeFeature.initialState(),
        env: HomeFeature.Environment? = nil
    ) -> TestStore<HomeFeature.Action, HomeFeature.State, HomeFeature.Environment> {
        TestStore(
            initial: initial,
            behavior: HomeFeature.behavior(),
            environment: env ?? mockEnv
        )
    }

    // MARK: - Initial state

    @Test func initialStateIsIdle() {
        let s = HomeFeature.initialState()
        #expect(s.documents == .idle)
        #expect(s.filePicker == .idle)
    }

    // MARK: - File picker lifecycle

    @Test func openFilePickerStartsLoadingFilePicker() {
        store().dispatch(.openFilePicker) { state in
            state.filePicker = state.filePicker.startLoading()
        }
    }

    @Test func filePickerDismissedResetsFilePicker() {
        var initial = HomeFeature.initialState()
        initial.filePicker = .loading(previous: nil)
        store(initial: initial).dispatch(.filePickerDismissed) { state in
            state.filePicker = .idle
        }
    }

    // MARK: - Document management

    @Test func newDocumentPrependsEmptyDocumentToLoadedList() {
        var initial = HomeFeature.initialState()
        initial.documents = .loaded([.validation])
        let s = store(initial: initial)
        let src = ActionSource(file: #file, function: #function, line: #line)
        s.dispatch(.newDocument, source: src)
        #expect(s.state.documents.loaded?.count == 2)
        #expect(s.state.documents.loaded?.first?.name == "Untitled")
        #expect(s.state.documents.loaded?.last == .validation)
    }

    @Test func newDocumentFromIdleInitializesWithEmpty() {
        let s = store()
        let src = ActionSource(file: #file, function: #function, line: #line)
        s.dispatch(.newDocument, source: src)
        #expect(s.state.documents.loaded?.count == 1)
        #expect(s.state.documents.loaded?.first?.name == "Untitled")
    }

    @Test func saveDocumentUpdatesExistingByID() {
        var initial = HomeFeature.initialState()
        let original = ModelDocument.validation
        initial.documents = .loaded([original])
        var updated = original
        updated.name = "Validation Updated"
        store(initial: initial).dispatch(.saveDocument(updated)) { state in
            state.documents = .loaded([updated])
        }
    }

    @Test func saveDocumentFromIdleInitializesWithDoc() {
        store().dispatch(.saveDocument(.validation)) { state in
            state.documents = .loaded([.validation])
        }
    }

    @Test func deleteDocumentRemovesByID() {
        var initial = HomeFeature.initialState()
        initial.documents = .loaded([.iodo131, .validation])
        store(initial: initial).dispatch(.deleteDocument(ModelDocument.validation.id)) { state in
            state.documents = .loaded([.iodo131])
        }
    }

    @Test func deleteDocumentNotInListIsNoOp() {
        var initial = HomeFeature.initialState()
        initial.documents = .loaded([.iodo131])
        let s = store(initial: initial)
        let source = ActionSource(file: #file, function: #function, line: #line)
        s.dispatch(.deleteDocument(ModelDocument.validation.id), source: source)
        #expect(s.state.documents == .loaded([.iodo131]))
    }

    // MARK: - importXML (synchronous side effects only)

    @Test func importXMLClosesFilePickerAndStartsLoadingDocuments() async {
        var initial = HomeFeature.initialState()
        initial.filePicker = .loading(previous: nil)
        initial.documents = .loaded([.iodo131])
        let s = store(initial: initial)
        // Phase 1: synchronous state changes
        s.dispatch(.importXML(Data())) { state in
            state.filePicker = .loaded()
            state.documents = .loading(previous: [.iodo131])
        }
        // Phase 2: run the async decode effect (NeverDecodesFactory always returns failure)
        await s.runEffects()
        // Phase 3: accept the importResult(.failure) the effect dispatched
        s.receive(HomeFeature.Action.prism.importResult) { result, state in
            state.filePicker = .idle
            if case .failure(let err) = result {
                state.documents = .failed(error: err, previous: [.iodo131])
            }
        }
    }

    // MARK: - importResult

    @Test func importResultSuccessAppendsDocumentAndResetsFilePicker() {
        var initial = HomeFeature.initialState()
        initial.documents = .loaded([.iodo131])
        initial.filePicker = .loaded()
        let doc = ModelDocument.validation
        store(initial: initial).dispatch(.importResult(.success(doc))) { state in
            state.filePicker = .idle
            state.documents = .loaded([.iodo131, doc])
        }
    }

    @Test func importResultFailureRecordsErrorAndResetsFilePicker() {
        var initial = HomeFeature.initialState()
        initial.documents = .loaded([.iodo131])
        initial.filePicker = .loaded()
        let err = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad XML"))
        store(initial: initial).dispatch(.importResult(.failure(err))) { state in
            state.filePicker = .idle
            state.documents = .failed(error: err, previous: [.iodo131])
        }
    }

    @Test func importResultSuccessFromIdleInitializesDocuments() {
        let doc = ModelDocument.validation
        store().dispatch(.importResult(.success(doc))) { state in
            state.filePicker = .idle
            state.documents = .loaded([doc])
        }
    }
}

// MARK: - mapState tests

@Suite("HomeFeature mapState")
@MainActor
struct HomeFeatureMapStateTests {

    @Test func cardsReflectLoadedDocuments() {
        var state = HomeFeature.initialState()
        state.documents = .loaded([.iodo131, .validation])
        let vs = HomeFeature.mapState(state)
        #expect(vs.cards.loaded?.count == 2)
        #expect(vs.cards.loaded?[0].name == ModelDocument.iodo131.name)
        #expect(vs.cards.loaded?[1].name == ModelDocument.validation.name)
    }

    @Test func cardsIdleWhenDocumentsIdle() {
        let state = HomeFeature.initialState()
        let vs = HomeFeature.mapState(state)
        #expect(vs.cards == .idle)
    }

    @Test func cardCompartmentAndConnectionCountsMatch() {
        var state = HomeFeature.initialState()
        state.documents = .loaded([.validation])  // 3 compartments, 3 connections
        let vs = HomeFeature.mapState(state)
        #expect(vs.cards.loaded?[0].compartmentCount == 3)
        #expect(vs.cards.loaded?[0].connectionCount == 3)
    }

    @Test func filePickerStateForwardedToViewState() {
        var state = HomeFeature.initialState()
        state.filePicker = .loading(previous: nil)
        let vs = HomeFeature.mapState(state)
        #expect(vs.filePicker == .loading(previous: nil))
    }
}

// MARK: - mapAction tests

/// mapAction round-trip: view actions translate to the expected domain actions.
@Suite("HomeFeature mapAction")
struct HomeFeatureMapActionTests {

    @Test func openFilePickerMapsToOpenFilePicker() {
        let action = HomeFeature.mapAction(.openFilePicker)
        #expect(HomeFeature.Action.prism.openFilePicker.preview(action) != nil)
    }

    @Test func filePickerDismissedMapsToFilePickerDismissed() {
        let action = HomeFeature.mapAction(.filePickerDismissed)
        #expect(HomeFeature.Action.prism.filePickerDismissed.preview(action) != nil)
    }

    @Test func newDocumentMapsToNewDocument() {
        let action = HomeFeature.mapAction(.newDocument)
        #expect(HomeFeature.Action.prism.newDocument.preview(action) != nil)
    }

    @Test func importXMLMapsToImportXML() {
        let data = Data("xml".utf8)
        let action = HomeFeature.mapAction(.importXML(data))
        #expect(HomeFeature.Action.prism.importXML.preview(action) == data)
    }

    @Test func editDocumentMapsToEdit() {
        let action = HomeFeature.mapAction(.editDocument(.validation))
        #expect(HomeFeature.Action.prism.edit.preview(action) == .validation)
    }

    @Test func calculateDocumentMapsToCalculate() {
        let action = HomeFeature.mapAction(.calculateDocument(.iodo131))
        #expect(HomeFeature.Action.prism.calculate.preview(action) == .iodo131)
    }

    @Test func deleteDocumentMapsToDeleteDocument() {
        let id = ModelDocument.validation.id
        let action = HomeFeature.mapAction(.deleteDocument(id))
        #expect(HomeFeature.Action.prism.deleteDocument.preview(action) == id)
    }

    @Test func saveDocumentMapsToSaveDocument() {
        let action = HomeFeature.mapAction(.saveDocument(.validation))
        #expect(HomeFeature.Action.prism.saveDocument.preview(action) == .validation)
    }
}

// MARK: - Snapshot tests

#if os(iOS) || os(tvOS)
import SwiftRexArchitecture
import SwiftUI

@Suite("HomeFeature Snapshots")
@MainActor
struct HomeFeatureSnapshotTests {

    private let env = HomeModule.Environment.alwaysFails

    private static let iPhoneLayout = SwiftUISnapshotLayout.fixed(width: 390,  height: 844)
    private static let iPadLayout   = SwiftUISnapshotLayout.fixed(width: 1194, height: 834)

    private func snapBoth<F: Feature>(
        _ feature: TestFeature<F>,
        named baseName: String,
        testName: String = #function,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async where F.Content: View {
        await feature.ignoringActions {
            assertSnapshot(of: feature.view, as: .image(layout: Self.iPhoneLayout),
                           named: "\(baseName)-iphone", file: file, testName: testName, line: line)
            assertSnapshot(of: feature.view, as: .image(layout: Self.iPadLayout),
                           named: "\(baseName)-ipad",   file: file, testName: testName, line: line)
        }
    }

    @Test func snapshotIdleState() async {
        let feature = TestFeature<HomeFeature>(environment: env)
        await snapBoth(feature, named: "home-idle")
    }

    @Test func snapshotLoadedDocuments() async {
        var initial = HomeFeature.initialState()
        initial.documents = .loaded([.iodo131, .validation])
        let feature = TestFeature<HomeFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "home-loaded")
    }

    @Test func snapshotEmptyDocumentList() async {
        var initial = HomeFeature.initialState()
        initial.documents = .loaded([])
        let feature = TestFeature<HomeFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "home-empty")
    }

    @Test func snapshotFilePickerOpen() async {
        var initial = HomeFeature.initialState()
        initial.documents = .loaded([.iodo131])
        initial.filePicker = .loading(previous: nil)
        let feature = TestFeature<HomeFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "home-file-picker-open")
    }

    @Test func snapshotImportFailed() async {
        let err = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "XML schema not supported"))
        var initial = HomeFeature.initialState()
        initial.documents = .failed(error: err, previous: [.iodo131])
        let feature = TestFeature<HomeFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "home-import-error")
    }

    @Test func snapshotLoadingDocuments() async {
        var initial = HomeFeature.initialState()
        initial.documents = .loading(previous: [.iodo131])
        let feature = TestFeature<HomeFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "home-loading")
    }
}
#endif
