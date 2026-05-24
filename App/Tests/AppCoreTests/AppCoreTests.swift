import AppCore
import AppDomain
import Domain
import Foundation
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

    private var successEnv: HomeFeature.Environment {
        .init { _ in
            .success(ModelDocument(
                name: "Imported Doc",
                description: "From XML",
                halfLife: 3.0,
                model: CompartmentalModel(
                    compartments: [
                        Compartment(id: "x", name: "X",
                                    follow: true, intake: true, dispose: false, fraction: 1.0)
                    ],
                    connections: []
                )
            ))
        }
    }

    private var failureEnv: HomeFeature.Environment {
        .init { _ in .failure(ParseError("bad XML")) }
    }

    private func store(
        initial: HomeFeature.State = HomeFeature.initialState(),
        env: HomeFeature.Environment? = nil
    ) -> TestStore<HomeFeature.Action, HomeFeature.State, HomeFeature.Environment> {
        TestStore(
            initial: initial,
            behavior: HomeFeature.behavior(),
            environment: env ?? successEnv
        )
    }

    // MARK: - Initial state

    @Test func initialStateHasDefaultDocumentsAndEmptyPath() {
        let s = HomeFeature.initialState()
        #expect(!s.documents.isEmpty)
        #expect(s.path.isEmpty)
        #expect(s.importError == nil)
        #expect(s.isImporting == false)
    }

    // MARK: - Navigation

    @Test func pushAppendsEditorRouteToPath() {
        store().dispatch(.push(.editor(.validation))) { state in
            state.path.append(.editor(.validation))
        }
    }

    @Test func pushCalculatorRouteToPath() {
        store().dispatch(.push(.calculator(.iodo131))) { state in
            state.path.append(.calculator(.iodo131))
        }
    }

    @Test func setPathReplacesEntirePath() {
        var initial = HomeFeature.initialState()
        initial.path = [.editor(.validation)]
        store(initial: initial).dispatch(.setPath([])) { state in
            state.path = []
        }
    }

    @Test func setPathWithMultipleRoutes() {
        store().dispatch(.setPath([.editor(.validation), .calculator(.iodo131)])) { state in
            state.path = [.editor(.validation), .calculator(.iodo131)]
        }
    }

    // MARK: - Document management

    @Test func newDocumentAppendsBlankDocument() {
        let source = ActionSource(file: #file, function: #function, line: #line)
        let s = store()
        let countBefore = s.state.documents.count
        s.dispatch(.newDocument, source: source)
        #expect(s.state.documents.count == countBefore + 1)
        #expect(s.state.documents.last?.name == "New Model")
    }

    @Test func saveDocumentUpdatesExistingByID() {
        var initial = HomeFeature.initialState()
        let original = ModelDocument.validation
        initial.documents = [original]
        var updated = original
        updated.name = "Validation Updated"
        store(initial: initial).dispatch(.saveDocument(updated)) { state in
            state.documents = [updated]
        }
    }

    @Test func saveDocumentAppendsWhenIDNotFound() {
        var initial = HomeFeature.initialState()
        initial.documents = [.iodo131]
        store(initial: initial).dispatch(.saveDocument(.validation)) { state in
            state.documents = [.iodo131, .validation]
        }
    }

    @Test func deleteDocumentRemovesByID() {
        var initial = HomeFeature.initialState()
        initial.documents = [.iodo131, .validation]
        store(initial: initial).dispatch(.deleteDocument(ModelDocument.validation.id)) { state in
            state.documents = [.iodo131]
        }
    }

    @Test func deleteDocumentNotInListIsNoOp() {
        var initial = HomeFeature.initialState()
        initial.documents = [.iodo131]
        let s = store(initial: initial)
        let source = ActionSource(file: #file, function: #function, line: #line)
        s.dispatch(.deleteDocument(ModelDocument.validation.id), source: source)
        #expect(s.state.documents.count == 1)
        #expect(s.state.documents[0].id == ModelDocument.iodo131.id)
    }

    // MARK: - XML import (async)

    @Test func importXMLSetsIsImportingThenAppendDocumentOnSuccess() async {
        let s = store(env: successEnv)
        s.dispatch(.importXML(Data("xml".utf8))) { state in
            state.isImporting = true
        }
        await s.runEffects()
        s.receive(HomeFeature.Action.prism.importResult) { result, state in
            if case .success(let doc) = result {
                state.documents.append(doc)
                state.isImporting = false
                state.importError = nil
            }
        }
        #expect(s.state.documents.last?.name == "Imported Doc")
        #expect(!s.state.isImporting)
    }

    @Test func importXMLSetsErrorOnFailure() async {
        let s = store(env: failureEnv)
        s.dispatch(.importXML(Data("bad".utf8))) { state in
            state.isImporting = true
        }
        await s.runEffects()
        s.receive(HomeFeature.Action.prism.importResult) { result, state in
            if case .failure(let err) = result {
                state.isImporting = false
                state.importError = err.message
            }
        }
        #expect(s.state.importError == "bad XML")
        #expect(!s.state.isImporting)
    }

    // MARK: - .importResult (dispatched directly)

    @Test func importResultSuccessAppendDocumentAndClearsImporting() {
        let doc = ModelDocument.validation
        var initial = HomeFeature.initialState()
        initial.isImporting = true
        store(initial: initial).dispatch(.importResult(.success(doc))) { state in
            state.documents.append(doc)
            state.isImporting = false
            state.importError = nil
        }
    }

    @Test func importResultFailureSetsErrorAndClearsImporting() {
        var initial = HomeFeature.initialState()
        initial.isImporting = true
        let err = ParseError("invalid compartment data")
        store(initial: initial).dispatch(.importResult(.failure(err))) { state in
            state.isImporting = false
            state.importError = err.message
        }
    }
}

// MARK: - mapState tests

@Suite("HomeFeature mapState")
@MainActor
struct HomeFeatureMapStateTests {

    @Test func cardsReflectDocuments() {
        var state = HomeFeature.initialState()
        state.documents = [.iodo131, .validation]
        let vs = HomeFeature.mapState(state)
        #expect(vs.cards.count == 2)
        #expect(vs.cards[0].name == ModelDocument.iodo131.name)
        #expect(vs.cards[1].name == ModelDocument.validation.name)
    }

    @Test func cardCompartmentAndConnectionCountsMatch() {
        var state = HomeFeature.initialState()
        state.documents = [.validation]  // 3 compartments, 3 connections
        let vs = HomeFeature.mapState(state)
        #expect(vs.cards[0].compartmentCount == 3)
        #expect(vs.cards[0].connectionCount == 3)
    }

    @Test func pathForwardedToViewState() {
        var state = HomeFeature.initialState()
        state.path = [.editor(.validation)]
        let vs = HomeFeature.mapState(state)
        #expect(vs.path == [.editor(.validation)])
    }

    @Test func importStatusForwardedToViewState() {
        var state = HomeFeature.initialState()
        state.isImporting = true
        state.importError = "oops"
        let vs = HomeFeature.mapState(state)
        #expect(vs.isImporting == true)
        #expect(vs.importError == "oops")
    }
}

// MARK: - mapAction tests

/// mapAction round-trip: view actions translate to the expected domain actions.
/// Uses `Prism.preview` rather than `==` because `HomeFeature.Action` is not `Equatable`.
@Suite("HomeFeature mapAction")
struct HomeFeatureMapActionTests {

    @Test func editDocumentMapsToEditorPushRoute() {
        let action = HomeFeature.mapAction(.editDocument(.validation))
        #expect(HomeFeature.Action.prism.push.preview(action) == .editor(.validation))
    }

    @Test func calculateDocumentMapsToCalculatorPushRoute() {
        let action = HomeFeature.mapAction(.calculateDocument(.iodo131))
        #expect(HomeFeature.Action.prism.push.preview(action) == .calculator(.iodo131))
    }

    @Test func newDocumentMapsToNewDocument() {
        let action = HomeFeature.mapAction(.newDocument)
        #expect(HomeFeature.Action.prism.newDocument.preview(action) != nil)
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

    @Test func setPathMapsToSetPath() {
        let path: [AppRoute] = [.editor(.validation)]
        let action = HomeFeature.mapAction(.setPath(path))
        #expect(HomeFeature.Action.prism.setPath.preview(action) == path)
    }

    @Test func pushMapsToMatchingRoute() {
        let action = HomeFeature.mapAction(.push(.editor(.iodo131)))
        #expect(HomeFeature.Action.prism.push.preview(action) == .editor(.iodo131))
    }
}

// MARK: - Snapshot tests

#if os(iOS) || os(tvOS)
import SwiftRexArchitecture
import SwiftUI

@Suite("HomeFeature Snapshots")
@MainActor
struct HomeFeatureSnapshotTests {

    private var env: HomeFeature.Environment {
        .init { _ in .failure(ParseError("previews don't parse")) }
    }

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
                as: .image(layout: .fixed(width: 390, height: 844)),
                named: name,
                file: file,
                testName: testName,
                line: line
            )
        }
    }

    @Test func snapshotDefaultHomeScreen() async {
        let feature = TestFeature<HomeFeature>(environment: env)
        await snap(feature, named: "home-default")
    }

    @Test func snapshotEmptyDocumentList() async {
        var initial = HomeFeature.initialState()
        initial.documents = []
        let feature = TestFeature<HomeFeature>(initial: initial, environment: env)
        await snap(feature, named: "home-empty")
    }

    @Test func snapshotImportingState() async {
        var initial = HomeFeature.initialState()
        initial.isImporting = true
        let feature = TestFeature<HomeFeature>(initial: initial, environment: env)
        await snap(feature, named: "home-importing")
    }

    @Test func snapshotImportError() async {
        var initial = HomeFeature.initialState()
        initial.importError = "XML schema version 2 not supported"
        let feature = TestFeature<HomeFeature>(initial: initial, environment: env)
        await snap(feature, named: "home-import-error")
    }
}
#endif
