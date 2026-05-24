import AppDomain
import Domain
import Foundation
import SwiftRex
import SwiftRexArchitecture

/// The root feature — owns both the navigation stack and the document library.
///
/// Merging navigation and document management into a single feature keeps
/// AppState flat and avoids a cross-feature routing layer: the `.editDocument`
/// and `.calculateDocument` view actions are mapped directly to `.push(route)`,
/// which both updates the path and carries the document snapshot into the route.
@Feature
public enum HomeFeature {

    // MARK: - State

    public struct State: Sendable, Equatable {
        /// Navigation stack path — drives `NavigationStack(path:)` in ContentView.
        public var path: [AppRoute] = []
        /// The canonical list of saved biokinetic models.
        public var documents: [ModelDocument] = [.iodo131, .validation]
        public var importError: String?
        public var isImporting: Bool = false

        public init() {}
    }

    // MARK: - Action

    @dynamicMemberLookup
    public enum Action: Sendable {
        // Navigation
        case push(AppRoute)
        case setPath([AppRoute])
        // Document management
        case newDocument
        case importXML(Data)
        case importResult(Result<ModelDocument, ParseError>)
        case saveDocument(ModelDocument)
        case deleteDocument(ModelDocument.ID)
    }

    // MARK: - Environment

    public struct Environment: Sendable {
        public var parseXML: @Sendable (Data) -> Result<ModelDocument, ParseError>
        public init(parseXML: @escaping @Sendable (Data) -> Result<ModelDocument, ParseError>) {
            self.parseXML = parseXML
        }
    }

    // MARK: - ViewModel

    public final class ViewModel {
        public struct DocumentCard: Identifiable, Sendable, Equatable {
            public var id: UUID
            public var name: String
            public var description: String
            public var halfLife: Double
            public var compartmentCount: Int
            public var connectionCount: Int
            public var tints: [CompartmentTint]
            public var document: ModelDocument
        }

        public struct ViewState: Sendable, Equatable {
            public var path: [AppRoute] = []
            public var cards: [DocumentCard] = []
            public var importError: String? = nil
            public var isImporting: Bool = false
        }

        @dynamicMemberLookup
        public enum ViewAction: Sendable {
            case push(AppRoute)
            case setPath([AppRoute])
            case newDocument
            case importXML(Data)
            case editDocument(ModelDocument)
            case calculateDocument(ModelDocument)
            case deleteDocument(ModelDocument.ID)
            case saveDocument(ModelDocument)
        }
    }

    // MARK: - Mappings

    public static let mapState: @MainActor @Sendable (State) -> ViewModel.ViewState = { state in
        ViewModel.ViewState(
            path: state.path,
            cards: state.documents.map { doc in
                ViewModel.DocumentCard(
                    id: doc.id,
                    name: doc.name,
                    description: doc.description,
                    halfLife: doc.halfLife,
                    compartmentCount: doc.model.compartments.count,
                    connectionCount: doc.model.connections.count,
                    tints: doc.model.compartments
                        .compactMap { doc.visuals[$0.id]?.tint }
                        .prefix(8)
                        .map { $0 },
                    document: doc
                )
            },
            importError: state.importError,
            isImporting: state.isImporting
        )
    }

    public static let mapAction: @Sendable (ViewModel.ViewAction) -> Action = { va in
        switch va {
        case .push(let r):               .push(r)
        case .setPath(let p):            .setPath(p)
        case .newDocument:               .newDocument
        case .importXML(let d):          .importXML(d)
        case .editDocument(let doc):     .push(.editor(doc))
        case .calculateDocument(let d):  .push(.calculator(d))
        case .deleteDocument(let id):    .deleteDocument(id)
        case .saveDocument(let doc):     .saveDocument(doc)
        }
    }

    // MARK: - Lifecycle

    public static func initialState() -> State { .init() }

    public static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, _ in
            switch action.action {
            case .push(let route):
                .reduce { $0.path.append(route) }

            case .setPath(let path):
                .reduce { $0.path = path }

            case .newDocument:
                .reduce { $0.documents.append(makeBlankDocument()) }

            case .importXML(let data):
                .reduce { $0.isImporting = true }
                .produce { env in
                    .just(.importResult(env.parseXML(data)))
                }

            case .importResult(.success(let doc)):
                .reduce {
                    $0.documents.append(doc)
                    $0.isImporting = false
                    $0.importError = nil
                }

            case .importResult(.failure(let err)):
                .reduce {
                    $0.isImporting = false
                    $0.importError = err.message
                }

            case .saveDocument(let doc):
                .reduce { state in
                    if let idx = state.documents.firstIndex(where: { $0.id == doc.id }) {
                        state.documents[idx] = doc
                    } else {
                        state.documents.append(doc)
                    }
                }

            case .deleteDocument(let id):
                .reduce { $0.documents.removeAll { $0.id == id } }
            }
        }
    }

    public typealias Content = HomeView
}

// MARK: - Helpers

private func makeBlankDocument() -> ModelDocument {
    let id = "a"
    let model = CompartmentalModel(
        compartments: [
            Compartment(id: id, name: "Compartment A",
                        follow: true, intake: true, dispose: false, fraction: 1.0)
        ],
        connections: []
    )
    return ModelDocument(
        name: "New Model",
        description: "",
        halfLife: 0,
        model: model,
        visuals: [id: CompartmentVisuals(x: 450, y: 310, tint: .steel)]
    )
}
