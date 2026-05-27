import AppDomain
import Core
import Domain
import FP
import Foundation
import Parser
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

    public typealias State = HomeModule.State

    // MARK: - Action

    public typealias Action = HomeModule.Action

    // MARK: - Environment

    public typealias Environment = HomeModule.Environment

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
            public var filePicker: Loading<Terminal, Never> = .idle
            public var cards: Loading<[DocumentCard], DecodingError> = .idle
        }

        @dynamicMemberLookup
        public enum ViewAction: Sendable {
            case openFilePicker
            case filePickerDismissed
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
            filePicker: state.filePicker,
            cards: state.documents.map { value in
                value.map { doc in
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
                }
            }
        )
    }

    public static let mapAction: @Sendable (ViewModel.ViewAction) -> Action = { va in
        switch va {
        case .openFilePicker:             .openFilePicker
        case .filePickerDismissed:        .filePickerDismissed
        case .newDocument:                .newDocument
        case .importXML(let d):           .importXML(d)
        case .editDocument(let doc):      .edit(document: doc)
        case .calculateDocument(let doc): .calculate(document: doc)
        case .deleteDocument(let id):     .deleteDocument(id)
        case .saveDocument(let doc):      .saveDocument(doc)
        }
    }

    // MARK: - Lifecycle

    public static func initialState() -> State { .init() }

    public static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, _ in
            switch action.action {
            case .openFilePicker:
                .reduce { $0.filePicker = $0.filePicker.startLoading() }

            case .filePickerDismissed:
                .reduce { $0.filePicker = .idle }

            case .newDocument:
                .reduce { $0.documents = .loaded([.empty] + ($0.documents.loadedOrPrevious ?? [])) }

            case .importXML(let data):
                // Transition filePicker to .loaded(()) so the isPresented binding
                // drops to false without triggering filePickerDismissed (the set
                // closure guards on filePicker.is(.loading)).
                .reduce { $0.filePicker = .loaded(); $0.documents = $0.documents.startLoading() }
                .produce { env in
                    .just(
                        .importResult(
                            env.xmlDecoder
                                .dataDecoder(for: IpenXmlModel.self)(data)
                                .map { $0.toCompartmentalModel() }
                                .map(\.asModelDocument)
                        )
                    )
                }

            case let .importResult(result):
                .reduce { state in
                    state.filePicker = .idle
                    state.documents = state.documents.applying(
                        Array.pure >>> curry(+)(state.documents.loadedOrPrevious ?? []) <£> result
                    )
                }

            case .saveDocument(let doc):
                .reduce { state in
                    let zoom = Loading<[ModelDocument], DecodingError>.prism.loaded >>> [ModelDocument].ix(id: doc.id)

                    if zoom.preview(state.documents) != nil {
                        state.documents = zoom.over(const(doc))(state.documents)
                    } else {
                        state.documents = .loaded([doc])
                    }
                }

            case .deleteDocument(let id):
                .reduce { state in
                    guard let loaded = state.documents.loaded else { return }
                    state.documents = .loaded(loaded.filter(\.id >>> notEquals(id)))
                }

            case .edit, .calculate:
                .doNothing
            }
        }
    }

    public typealias Content = HomeView
}
