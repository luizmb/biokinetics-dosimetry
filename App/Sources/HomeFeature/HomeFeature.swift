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
            public var field: ModelField
            public var halfLife: Double
            public var compartmentCount: Int
            public var connectionCount: Int
            public var tints: [CompartmentTint]
            public var document: ModelDocument
        }

        public struct ViewState: Sendable, Equatable {
            public var filePicker: Loading<Terminal, Never> = .idle
            public var cards: Loading<[DocumentCard], DecodingError> = .idle
            public var importErrorMessage: String? = nil
            public var isCreationSheetOpen: Bool = false
            public var draftField: ModelField = .generic
            public var draftName: String = ""
        }

        @dynamicMemberLookup
        public enum ViewAction: Sendable {
            case openFilePicker
            case filePickerDismissed
            case openCreationSheet
            case dismissCreationSheet
            case setDraftField(ModelField)
            case setDraftName(String)
            case newDocument(field: ModelField, name: String)
            case importXML(Data)
            case importJSON(Data)
            case importCSV(Data)
            case editDocument(ModelDocument)
            case calculateDocument(ModelDocument)
            case deleteDocument(ModelDocument.ID)
            case duplicateDocument(ModelDocument.ID)
            case saveDocument(ModelDocument)
        }
    }

    // MARK: - Mappings

    public static let mapState: @MainActor @Sendable (State) -> ViewModel.ViewState = { state in
        let importError: String? = state.documents.failed.map { $0.0.localizedDescription }
        return ViewModel.ViewState(
            filePicker: state.filePicker,
            cards: state.documents.map { value in
                value.map { doc in
                    ViewModel.DocumentCard(
                        id: doc.id,
                        name: doc.name,
                        description: doc.description,
                        field: doc.field,
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
            },
            importErrorMessage: importError,
            isCreationSheetOpen: state.isCreationSheetOpen,
            draftField: state.draftField,
            draftName: state.draftName
        )
    }

    public static let mapAction: @Sendable (ViewModel.ViewAction) -> Action = { va in
        switch va {
        case .openFilePicker:             .openFilePicker
        case .filePickerDismissed:        .filePickerDismissed
        case .openCreationSheet:          .openCreationSheet
        case .dismissCreationSheet:       .dismissCreationSheet
        case .setDraftField(let f):       .setDraftField(f)
        case .setDraftName(let n):        .setDraftName(n)
        case .newDocument(let f, let n):  .newDocument(field: f, name: n)
        case .importXML(let d):           .importXML(d)
        case .importJSON(let d):          .importJSON(d)
        case .importCSV(let d):           .importCSV(d)
        case .editDocument(let doc):      .edit(document: doc)
        case .calculateDocument(let doc): .calculate(document: doc)
        case .deleteDocument(let id):     .deleteDocument(id)
        case .duplicateDocument(let id):  .duplicateDocument(id)
        case .saveDocument(let doc):      .saveDocument(doc)
        }
    }

    // MARK: - Lifecycle

    public static func initialState() -> State { .init() }

    public static func behavior() -> Behavior<Action, State, Environment> {
        typealias C = Consequence<State, Environment, Action>
        return .handle { action, context in
            switch action {
            case .openFilePicker:
                return C.reduce { $0.filePicker = $0.filePicker.startLoading() }

            case .filePickerDismissed:
                return C.reduce { $0.filePicker = .idle }

            case .openCreationSheet:
                return C.reduce { $0.isCreationSheetOpen = true; $0.draftField = .generic; $0.draftName = "" }

            case .dismissCreationSheet:
                return C.reduce { $0.isCreationSheetOpen = false }

            case .setDraftField(let f):
                return C.reduce { $0.draftField = f }

            case .setDraftName(let n):
                return C.reduce { $0.draftName = n }

            case .loadDocuments:
                return C.produce { ctx in
                    .just(.loadResult(ctx.environment.loadAllDocuments()))
                }

            case .loadResult(let result):
                if case .success(let docs) = result, docs.isEmpty {
                    // First launch: seed example documents, save them, then show them.
                    let seeds = SeedDocuments.all + SeedDocuments.icrpModels
                    return C.reduce { $0.documents = .loaded(seeds) }
                        .produce { ctx in
                            seeds.forEach { _ = ctx.environment.saveDocument($0) }
                            return .empty
                        }
                }
                return C.reduce { state in
                    if case .success(let docs) = result {
                        state.documents = .loaded(docs)
                    }
                    // On failure, leave existing state — user can still work.
                }

            case .newDocument(let field, let name):
                let lingo = field.lingo
                let nuclide = Nuclide(id: "n0", name: lingo.substanceName, halfLife: 0)
                let model = CompartmentalModel(nuclides: [nuclide], compartments: [], connections: [])
                let newDoc = ModelDocument(
                    name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : name,
                    field: field,
                    model: model
                )
                return C.reduce {
                    $0.isCreationSheetOpen = false
                    $0.documents = .loaded([newDoc] + ($0.documents.loadedOrPrevious ?? []))
                }
                .produce { ctx in
                    _ = ctx.environment.saveDocument(newDoc)
                    return .just(.edit(document: newDoc))
                }

            case .importXML(let data):
                return C.reduce { $0.filePicker = .loaded(); $0.documents = $0.documents.startLoading() }
                    .produce { ctx in
                        .just(
                            .importResult(
                                ctx.environment.xmlDecoder
                                    .dataDecoder(for: IpenXmlModel.self)(data)
                                    .map { xmlModel -> ModelDocument in
                                        let model = xmlModel.toCompartmentalModel()
                                        return ModelDocument(
                                            name: xmlModel.modelo?.name ?? "Imported Model",
                                            description: xmlModel.modelo?.description ?? "",
                                            model: model,
                                            visuals: Self.visuals(from: xmlModel, model: model)
                                        )
                                    }
                            )
                        )
                    }

            case .importJSON(let data):
                return C.reduce { $0.filePicker = .loaded(); $0.documents = $0.documents.startLoading() }
                    .produce { ctx in
                        .just(.importResult(ctx.environment.jsonDecoder.dataDecoder(for: ModelDocument.self)(data)))
                    }

            case .importCSV(let data):
                return C.reduce { $0.filePicker = .loaded(); $0.documents = $0.documents.startLoading() }
                    .produce { _ in
                        let result = parseCSVRateMatrix(data: data)
                            .map { model -> ModelDocument in
                                var doc = model.asModelDocument
                                doc.name = "Imported CSV Model"
                                return doc
                            }
                            .mapError { err in
                                DecodingError.dataCorrupted(
                                    DecodingError.Context(codingPath: [], debugDescription: err.localizedDescription)
                                )
                            }
                        return .just(.importResult(result))
                    }

            case let .importResult(result):
                return C.reduce { state in
                    state.filePicker = .idle
                    state.documents = state.documents.applying(
                        Array.pure >>> curry(+)(state.documents.loadedOrPrevious ?? []) <£> result
                    )
                }
                .produce { ctx in
                    guard case .success(let doc) = result else { return .empty }
                    _ = ctx.environment.saveDocument(doc)
                    return .empty
                }

            case .saveDocument(let doc):
                return C.reduce { state in
                    let zoom = Loading<[ModelDocument], DecodingError>.prism.loaded >>> [ModelDocument].ix(id: doc.id)
                    if zoom.preview(state.documents) != nil {
                        state.documents = zoom.over(const(doc))(state.documents)
                    } else {
                        state.documents = .loaded([doc])
                    }
                }
                .produce { ctx in
                    _ = ctx.environment.saveDocument(doc)
                    return .empty
                }

            case .duplicateDocument(let id):
                return duplicateConsequence(id: id, context: context)

            case .deleteDocument(let id):
                return C.reduce { state in
                    guard let loaded = state.documents.loaded else { return }
                    state.documents = .loaded(loaded.filter(\.id >>> notEquals(id)))
                }
                .produce { ctx in
                    _ = ctx.environment.deleteDocument(id)
                    return .empty
                }

            case .edit, .calculate:
                return .doNothing
            }
        }
    }

    public typealias Content = HomeView

    // MARK: - Private helpers

    @MainActor
    private static func duplicateConsequence(
        id: ModelDocument.ID,
        context: PreReducerContext<State>
    ) -> Consequence<State, Environment, Action> {
        typealias C = Consequence<State, Environment, Action>
        guard let original = (context.stateBefore ?? State()).documents.loaded?.first(where: { $0.id == id }) else {
            return C.reduce { _ in }
        }
        var mutable = original
        mutable.id = UUID()
        mutable.name = original.name + " (Copy)"
        let copy = mutable
        return C.reduce { state in
            state.documents = .loaded((state.documents.loadedOrPrevious ?? []) + [copy])
        }
        .produce { ctx in
            _ = ctx.environment.saveDocument(copy)
            return .empty
        }
    }

    // MARK: - Visual layout helpers

    /// Builds `CompartmentVisuals` for an imported IPEN XML model.
    ///
    /// **Strategy (in priority order):**
    /// 1. If every compartment has `PosLeft`/`PosTop` data, use those CBT
    ///    pixel coordinates scaled to the 900×620 canvas. This preserves the
    ///    original topology layout designed by the model author.
    /// 2. Fallback: circular layout with radius 165 — small enough that the
    ///    full circle fits inside the iPhone's default visible canvas window
    ///    (canvas x ∈ [255, 645] at scale=1, offset=0).
    private static func visuals(
        from xmlModel: IpenXmlModel,
        model: CompartmentalModel
    ) -> [String: CompartmentVisuals] {
        let tints = CompartmentTint.allCases

        // Collect raw CBT centre-points for every compartment that has position data.
        let rawPos: [Int: (x: Double, y: Double)] = xmlModel.compartments.reduce(into: [:]) { d, c in
            guard let left = c.posLeft, let top = c.posTop else { return }
            let cx = Double(left) + Double(c.posWidth  ?? 100) * 0.5
            let cy = Double(top)  + Double(c.posHeight ?? 50)  * 0.5
            d[c.number] = (cx, cy)
        }

        let margin = 50.0   // canvas-unit padding on each side
        let canvasW = 900.0, canvasH = 620.0

        var xmlPos: [Int: (x: Double, y: Double)] = [:]
        if rawPos.count == xmlModel.compartments.count {
            // Normalise from actual data bounds → fit everything inside the canvas.
            let xs = rawPos.values.map(\.x), ys = rawPos.values.map(\.y)
            let minX = xs.min() ?? 0, maxX = xs.max() ?? 1
            let minY = ys.min() ?? 0, maxY = ys.max() ?? 1
            let rangeX = max(maxX - minX, 1), rangeY = max(maxY - minY, 1)
            // Uniform scale so relative positions are preserved (no distortion).
            let scale = min((canvasW - 2 * margin) / rangeX,
                            (canvasH - 2 * margin) / rangeY)
            // Center the scaled model in the canvas.
            let offsetX = (canvasW - rangeX * scale) / 2
            let offsetY = (canvasH - rangeY * scale) / 2
            for (number, p) in rawPos {
                xmlPos[number] = ((p.x - minX) * scale + offsetX,
                                  (p.y - minY) * scale + offsetY)
            }
        }

        let useXML = xmlPos.count == xmlModel.compartments.count
        let cx = 450.0, cy = 310.0, radius = 165.0
        return Dictionary(uniqueKeysWithValues: model.compartments.enumerated().map { idx, comp in
            let pos: (Double, Double)
            if useXML, let n = Int(comp.id), let p = xmlPos[n] {
                pos = p
            } else {
                let angle = 2 * .pi * Double(idx) / Double(max(model.compartments.count, 1)) - .pi / 2
                pos = (cx + radius * cos(angle), cy + radius * sin(angle))
            }
            return (comp.id, CompartmentVisuals(x: pos.0, y: pos.1, tint: tints[idx % tints.count]))
        })
    }
}
