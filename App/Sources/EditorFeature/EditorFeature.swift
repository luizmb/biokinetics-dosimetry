import AppDomain
import Domain
import Foundation
import SwiftRex
import SwiftRexArchitecture

// MARK: - EditorFeature

@Feature
public enum EditorFeature {

    // MARK: - State

    public struct State: Sendable, Equatable {
        /// The document being edited (mutated in place by all editor actions).
        public var document: ModelDocument = .empty
        /// Currently selected compartment ID (nil = nothing selected).
        public var selectedCompartmentId: String?
        /// Currently selected connection "K-id" (nil = nothing / compartment selected).
        public var selectedLinkIndex: Int?
        /// Which tab is active in the right inspector panel.
        public var inspectorTab: InspectorTab = .details
        public var isLeftPanelVisible: Bool = true
        public var isRightPanelVisible: Bool = true
        public var showKValues: Bool = false
        /// Guided link-creation state.
        public var linkingState: LinkingState = .idle
        /// Canvas viewport: logical offset and zoom scale.
        public var canvasOffset: CanvasPoint = CanvasPoint(x: 0, y: 0)
        public var canvasScale: Double = 1.0

        public init() {
        }
    }

    public enum InspectorTab: String, Sendable, Equatable {
        case details, relationships
    }

    public enum LinkingState: Sendable, Equatable {
        case idle
        case awaitingFrom
        case awaitingTo(fromId: String)
    }

    public struct CanvasPoint: Sendable, Equatable {
        public var x, y: Double
        public init(x: Double, y: Double) { self.x = x; self.y = y }
    }

    // MARK: - Action

    @dynamicMemberLookup
    public enum Action: Sendable {
        case load(ModelDocument)
        // Selection
        case selectCompartment(String?)
        case selectLink(Int?)
        case setInspectorTab(InspectorTab)
        // Compartment mutations
        case addCompartment(CompartmentTint)
        case updateCompartmentName(id: String, name: String)
        case updateCompartmentFollow(id: String, value: Bool)
        case updateCompartmentDispose(id: String, value: Bool)
        case updateCompartmentIntake(id: String, value: Bool)
        case moveCompartment(id: String, x: Double, y: Double)
        case deleteCompartment(id: String)
        // Link mutations
        case beginLinking
        case linkStep(String)     // tap source then target compartment
        case cancelLinking
        case updateLinkRate(index: Int, rate: Double)
        case deleteLink(index: Int)
        // Canvas
        case setCanvasTransform(offsetX: Double, offsetY: Double, scale: Double)
        // Panels
        case toggleLeftPanel
        case toggleRightPanel
        case toggleKValues
        // Save
        case save
    }

    // MARK: - Environment

    public typealias Environment = Void

    // MARK: - ViewModel

    public final class ViewModel {
        public struct CompartmentRow: Identifiable, Sendable, Equatable {
            public var id: String
            public var name: String
            public var tint: CompartmentTint
            public var x, y: Double
            public var isSelected: Bool
            public var follow, intake, dispose: Bool
            public var fraction: Double
        }

        public struct LinkRow: Identifiable, Sendable, Equatable {
            public var id: Int
            public var fromId: String
            public var fromName: String
            public var fromTint: CompartmentTint
            public var toId: String
            public var toName: String
            public var toTint: CompartmentTint
            public var rate: Double
        }

        public struct ViewState: Sendable, Equatable {
            public var documentName: String = ""
            public var halfLife: Double = 0
            public var compartments: [CompartmentRow] = []
            public var links: [LinkRow] = []
            public var selectedCompartmentId: String?
            public var selectedLinkIndex: Int?
            public var inspectorTab: InspectorTab = .details
            public var isLeftPanelVisible: Bool = true
            public var isRightPanelVisible: Bool = true
            public var showKValues: Bool = false
            public var linkingState: LinkingState = .idle
            public var canvasOffsetX: Double = 0
            public var canvasOffsetY: Double = 0
            public var canvasScale: Double = 1
        }

        @dynamicMemberLookup
        public enum ViewAction: Sendable {
            case selectCompartment(String?)
            case selectLink(Int?)
            case setInspectorTab(InspectorTab)
            case addCompartment(CompartmentTint)
            case updateCompartmentName(id: String, name: String)
            case updateCompartmentFollow(id: String, value: Bool)
            case updateCompartmentDispose(id: String, value: Bool)
            case updateCompartmentIntake(id: String, value: Bool)
            case moveCompartment(id: String, x: Double, y: Double)
            case deleteCompartment(id: String)
            case beginLinking
            case linkStep(String)
            case cancelLinking
            case updateLinkRate(index: Int, rate: Double)
            case deleteLink(index: Int)
            case setCanvasTransform(offsetX: Double, offsetY: Double, scale: Double)
            case toggleLeftPanel
            case toggleRightPanel
            case toggleKValues
            case save
        }
    }

    // MARK: - Mappings

    public static let mapState: @MainActor @Sendable (State) -> ViewModel.ViewState = { state in
        let doc = state.document
        let compartments = doc.model.compartments.map { c -> ViewModel.CompartmentRow in
            let vis = doc.visuals[c.id]
            return ViewModel.CompartmentRow(
                id: c.id,
                name: c.name,
                tint: vis?.tint ?? .steel,
                x: vis?.x ?? 450,
                y: vis?.y ?? 310,
                isSelected: state.selectedCompartmentId == c.id,
                follow: c.follow,
                intake: c.intake,
                dispose: c.dispose,
                fraction: c.fraction
            )
        }
        let links = doc.model.connections.enumerated().map { idx, conn -> ViewModel.LinkRow in
            let fromC = doc.model.compartments.first { $0.id == conn.from }
            let toC   = doc.model.compartments.first { $0.id == conn.to }
            return ViewModel.LinkRow(
                id: idx,
                fromId: conn.from,
                fromName: fromC?.name ?? conn.from,
                fromTint: doc.visuals[conn.from]?.tint ?? .steel,
                toId: conn.to,
                toName: toC?.name ?? conn.to,
                toTint: doc.visuals[conn.to]?.tint ?? .steel,
                rate: conn.rate
            )
        }
        return ViewModel.ViewState(
            documentName: doc.name,
            halfLife: doc.halfLife,
            compartments: compartments,
            links: links,
            selectedCompartmentId: state.selectedCompartmentId,
            selectedLinkIndex: state.selectedLinkIndex,
            inspectorTab: state.inspectorTab,
            isLeftPanelVisible: state.isLeftPanelVisible,
            isRightPanelVisible: state.isRightPanelVisible,
            showKValues: state.showKValues,
            linkingState: state.linkingState,
            canvasOffsetX: state.canvasOffset.x,
            canvasOffsetY: state.canvasOffset.y,
            canvasScale: state.canvasScale
        )
    }

    public static let mapAction: @Sendable (ViewModel.ViewAction) -> Action = { va in
        switch va {
        case .selectCompartment(let id):               .selectCompartment(id)
        case .selectLink(let idx):                     .selectLink(idx)
        case .setInspectorTab(let tab):                .setInspectorTab(tab)
        case .addCompartment(let tint):                .addCompartment(tint)
        case .updateCompartmentName(let id, let n):    .updateCompartmentName(id: id, name: n)
        case .updateCompartmentFollow(let id, let v):  .updateCompartmentFollow(id: id, value: v)
        case .updateCompartmentDispose(let id, let v): .updateCompartmentDispose(id: id, value: v)
        case .updateCompartmentIntake(let id, let v):  .updateCompartmentIntake(id: id, value: v)
        case .moveCompartment(let id, let x, let y):   .moveCompartment(id: id, x: x, y: y)
        case .deleteCompartment(let id):               .deleteCompartment(id: id)
        case .beginLinking:                            .beginLinking
        case .linkStep(let id):                        .linkStep(id)
        case .cancelLinking:                           .cancelLinking
        case .updateLinkRate(let idx, let r):          .updateLinkRate(index: idx, rate: r)
        case .deleteLink(let idx):                     .deleteLink(index: idx)
        case .setCanvasTransform(let ox, let oy, let s): .setCanvasTransform(offsetX: ox, offsetY: oy, scale: s)
        case .toggleLeftPanel:                         .toggleLeftPanel
        case .toggleRightPanel:                        .toggleRightPanel
        case .toggleKValues:                           .toggleKValues
        case .save:                                    .save
        }
    }

    // MARK: - Lifecycle

    public static func initialState() -> State { .init() }

    public static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, _ in
            switch action.action {
            case .load(let doc):
                .reduce {
                    $0.document = doc
                    $0.selectedCompartmentId = nil
                    $0.selectedLinkIndex = nil
                    $0.linkingState = .idle
                    $0.canvasOffset = CanvasPoint(x: 0, y: 0)
                    $0.canvasScale = 1.0
                }

            case .selectCompartment(let id):
                .reduce {
                    $0.selectedCompartmentId = id
                    $0.selectedLinkIndex = nil
                }

            case .selectLink(let idx):
                .reduce {
                    $0.selectedLinkIndex = idx
                    $0.selectedCompartmentId = nil
                }

            case .setInspectorTab(let tab):
                .reduce { $0.inspectorTab = tab }

            case .addCompartment(let tint):
                .reduce { state in
                    let id = UUID().uuidString.prefix(8).lowercased()
                    let idStr = String(id)
                    let compartment = Compartment(
                        id: idStr, name: "New Compartment",
                        follow: false, intake: false, dispose: false, fraction: 0
                    )
                    state.document.model = CompartmentalModel(
                        compartments: state.document.model.compartments + [compartment],
                        connections: state.document.model.connections
                    )
                    state.document.visuals[idStr] = CompartmentVisuals(x: 450, y: 310, tint: tint)
                    state.selectedCompartmentId = idStr
                    state.selectedLinkIndex = nil
                    state.isRightPanelVisible = true
                    state.inspectorTab = .details
                }

            case .updateCompartmentName(let id, let name):
                .reduce { state in
                    state.document.model = CompartmentalModel(
                        compartments: state.document.model.compartments.map {
                            $0.id == id ? Compartment(id: $0.id, name: name, follow: $0.follow,
                                                      intake: $0.intake, dispose: $0.dispose,
                                                      fraction: $0.fraction) : $0
                        },
                        connections: state.document.model.connections
                    )
                }

            case .updateCompartmentFollow(let id, let value):
                .reduce { state in
                    state.document.model = state.document.model.updatingCompartment(id: id) {
                        Compartment(id: $0.id, name: $0.name, follow: value,
                                    intake: $0.intake, dispose: $0.dispose, fraction: $0.fraction)
                    }
                }

            case .updateCompartmentDispose(let id, let value):
                .reduce { state in
                    state.document.model = state.document.model.updatingCompartment(id: id) {
                        Compartment(id: $0.id, name: $0.name, follow: $0.follow,
                                    intake: $0.intake, dispose: value, fraction: $0.fraction)
                    }
                }

            case .updateCompartmentIntake(let id, let value):
                .reduce { state in
                    state.document.model = state.document.model.updatingCompartment(id: id) {
                        Compartment(id: $0.id, name: $0.name, follow: $0.follow,
                                    intake: value, dispose: $0.dispose, fraction: $0.fraction)
                    }
                }

            case .moveCompartment(let id, let x, let y):
                .reduce { state in
                    if var vis = state.document.visuals[id] {
                        vis.x = x; vis.y = y
                        state.document.visuals[id] = vis
                    }
                }

            case .deleteCompartment(let id):
                .reduce { state in
                    state.document.model = CompartmentalModel(
                        compartments: state.document.model.compartments.filter { $0.id != id },
                        connections: state.document.model.connections.filter {
                            $0.from != id && $0.to != id
                        }
                    )
                    state.document.visuals.removeValue(forKey: id)
                    if state.selectedCompartmentId == id { state.selectedCompartmentId = nil }
                }

            case .beginLinking:
                .reduce { $0.linkingState = .awaitingFrom }

            case .linkStep(let id):
                .reduce { state in
                    switch state.linkingState {
                    case .idle:
                        break
                    case .awaitingFrom:
                        state.linkingState = .awaitingTo(fromId: id)
                    case .awaitingTo(let fromId):
                        guard fromId != id else {
                            state.linkingState = .idle
                            break
                        }
                        let conn = CompartmentConnection(from: fromId, to: id, rate: 0.1)
                        state.document.model = CompartmentalModel(
                            compartments: state.document.model.compartments,
                            connections: state.document.model.connections + [conn]
                        )
                        let newIdx = state.document.model.connections.count - 1
                        state.selectedLinkIndex = newIdx
                        state.selectedCompartmentId = nil
                        state.linkingState = .idle
                        state.isRightPanelVisible = true
                    }
                }

            case .cancelLinking:
                .reduce { $0.linkingState = .idle }

            case .updateLinkRate(let idx, let rate):
                .reduce { state in
                    guard idx < state.document.model.connections.count else { return }
                    let old = state.document.model.connections[idx]
                    let updated = CompartmentConnection(from: old.from, to: old.to, rate: rate)
                    var conns = state.document.model.connections
                    conns[idx] = updated
                    state.document.model = CompartmentalModel(
                        compartments: state.document.model.compartments,
                        connections: conns
                    )
                }

            case .deleteLink(let idx):
                .reduce { state in
                    guard idx < state.document.model.connections.count else { return }
                    var conns = state.document.model.connections
                    conns.remove(at: idx)
                    state.document.model = CompartmentalModel(
                        compartments: state.document.model.compartments,
                        connections: conns
                    )
                    if state.selectedLinkIndex == idx { state.selectedLinkIndex = nil }
                }

            case .setCanvasTransform(let ox, let oy, let scale):
                .reduce { state in
                    state.canvasOffset = CanvasPoint(x: ox, y: oy)
                    state.canvasScale = max(0.2, min(5.0, scale))
                }

            case .toggleLeftPanel:
                .reduce { $0.isLeftPanelVisible.toggle() }

            case .toggleRightPanel:
                .reduce { $0.isRightPanelVisible.toggle() }

            case .toggleKValues:
                .reduce { $0.showKValues.toggle() }

            case .save:
                .doNothing   // Handled by AppCoordinator via environment (future)
            }
        }
    }

    public typealias Content = EditorView
}
