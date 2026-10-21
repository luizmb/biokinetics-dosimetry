import AppDomain
import Domain
import Foundation
import SwiftRex
import SwiftUI
import Localization
import SwiftRexArchitecture

// MARK: - EditorFeature

@Feature
public enum EditorFeature {

    // MARK: - State

    public struct State: Sendable, Equatable {
        /// The document being edited (mutated in place by all editor actions).
        public var document: ModelDocument = .empty
        /// The screen's traits, from the world through the app's state (see `DeviceTraits`).
        public var traits: DeviceTraits = .initial
        /// What is being typed into a number field, by field, until the field is left: the text
        /// stays as typed while it is on its way to a number ("", "0", "0,"), and the value follows
        /// only text that reads as one.
        public var numberDrafts: [NumberField: String] = [:]
        /// Currently selected compartment ID (nil = nothing selected).
        public var selectedCompartmentId: String?
        /// Currently selected connection "K-id" (nil = nothing / compartment selected).
        public var selectedLinkIndex: Int?
        /// Which tab is active in the right inspector panel.
        public var inspectorTab: InspectorTab = .details
        /// Which page the left panel shows: the document's settings, or what the model is made of.
        public var modelTab: ModelTab = .document
        /// A transfer being put together in the inspector: its ends, until both are chosen and it
        /// is created. While there is one, the inspector shows it rather than the selection.
        public var transferDraft: TransferDraft? = nil
        /// The panels beside the canvas when there is room for them: each shown or hidden on its own.
        public var isLeftPanelVisible: Bool = true
        public var isRightPanelVisible: Bool = true
        /// The one panel over the canvas when there isn't (a phone): in a sheet, or floating.
        public var overlayPanel: EditorPanel? = nil
        public var showKValues: Bool = false
        /// Canvas viewport: logical offset and zoom scale.
        public var canvasOffset: CanvasPoint = CanvasPoint(x: 0, y: 0)
        public var canvasScale: Double = 1.0
        /// Origin captured when a compartment drag begins; nil when no drag is in progress.
        public var compartmentDragOrigin: CompartmentDragOrigin? = nil
        /// Canvas-pan origin (nil when no pan is in progress).
        /// The pan or pinch in progress: the transform and touches it measures from; `nil` between
        /// gestures.
        public var canvasTouchSession: CanvasTouchSession? = nil
        /// While two fingers zoom, where the canvas will land; committed to `canvasOffset` /
        /// `canvasScale` when they lift. Until then the view shows the committed layout scaled to
        /// it as one image, so nothing (the glass above all) is rebuilt per frame.
        public var canvasPinchPreview: CanvasTransform? = nil
        /// The variant key currently being edited (nil = base model).
        public var editingVariant: String? = nil
        /// The variant key currently being renamed (nil = not renaming).
        public var renamingVariant: String? = nil
        /// Draft name while renaming a variant.
        public var variantRenameDraft: String = ""

        public init() {
        }

        /// A fresh editor for `document`.
        ///
        /// Seeding is construction: navigation appends a screen that is already complete, so there is
        /// never a half-initialised editor for someone else to finish assembling. Every field `.load`
        /// resets — selection, the transfer draft, canvas transform — is already an `init()` default, so this is
        /// exactly a freshly-loaded editor.
        public init(document: ModelDocument) {
            self.init()
            self.document = document
        }

        // MARK: Variant-aware model access

        /// The model currently being edited — base model or a named variant.
        var currentModel: CompartmentalModel {
            editingVariant.flatMap { document.variants[$0] } ?? document.model
        }

        /// Writes the model back to the correct slot (base or variant).
        mutating func setCurrentModel(_ model: CompartmentalModel) {
            if let key = editingVariant {
                document.variants[key] = model
            } else {
                document.model = model
            }
        }

        /// Propagates any nuclide change on the base model to all variants.
        /// How the screen shows its panels, from its traits.
        public var layout: EditorLayout { EditorLayout(traits) }

        /// Whether `panel` is open, in the way the layout shows panels.
        public func isOpen(_ panel: EditorPanel) -> Bool {
            switch (layout, panel) {
            case (.docked, .modelList): isLeftPanelVisible
            case (.docked, .inspector): isRightPanelVisible
            case (.floating, _), (.sheets, _): overlayPanel == panel
            }
        }

        /// Opens or closes `panel`: beside the canvas on its own, or over it one at a time.
        mutating func setPanel(_ panel: EditorPanel, _ isOpen: Bool) {
            switch (layout, panel) {
            case (.docked, .modelList): isLeftPanelVisible = isOpen
            case (.docked, .inspector): isRightPanelVisible = isOpen
            case (.floating, _), (.sheets, _): overlayPanel = isOpen ? panel : overlayPanel == panel ? nil : overlayPanel
            }
        }

        mutating func syncNuclidesToVariants() {
            let nuclides = document.model.nuclides
            for key in document.variants.keys {
                if let v = document.variants[key] {
                    document.variants[key] = v.with(nuclides: nuclides)
                }
            }
        }
    }

    public enum InspectorTab: String, Sendable, Equatable, CaseIterable {
        case details, relationships
    }

    /// The left panel's pages: the document's own settings, and the list of what the model is
    /// made of (compartments and transfers), where things are picked, edited, added and deleted.
    public enum ModelTab: String, Sendable, Equatable, CaseIterable {
        case document, contents
    }

    /// The two ends of a transfer not yet made.
    public struct TransferDraft: Sendable, Equatable {
        public var from: String?
        public var to: String?
        public init(from: String? = nil, to: String? = nil) {
            self.from = from
            self.to = to
        }

        /// Both ends chosen, and not the same compartment.
        public var isComplete: Bool { from != nil && to != nil && from != to }
    }

    /// The editor's two panels: the model's list, and the inspector of what is selected.
    public enum EditorPanel: Sendable, Equatable {
        case modelList, inspector
    }

    /// How the editor shows its panels: beside the canvas on a pad, floating over it on a phone
    /// on its side (one at a time), in a sheet on a phone held upright.
    public enum EditorLayout: Sendable, Equatable {
        case docked, floating, sheets

        public init(_ traits: DeviceTraits) {
            self = traits.isCompactHeight ? .floating : traits.isCompactWidth ? .sheets : .docked
        }
    }

    public struct CanvasPoint: Sendable, Equatable {
        public var x: Double
        public var y: Double
        public init(x: Double, y: Double) { self.x = x; self.y = y }
    }

    /// Where the canvas sits: `offset` in view points, `scale` its zoom.
    public struct CanvasTransform: Sendable, Equatable {
        public var offset: CanvasPoint
        public var scale: Double
        public init(offset: CanvasPoint, scale: Double) { self.offset = offset; self.scale = scale }
    }

    /// The fingers on the canvas, as the view reports them: each touch's location in the canvas
    /// view's points, by touch id.
    public struct CanvasTouches: Sendable, Equatable {
        public var touches: [Int: CanvasPoint]
        /// The middle of the canvas view: the transform's origin.
        public var viewCenter: CanvasPoint
        public init(touches: [Int: CanvasPoint], viewCenter: CanvasPoint) {
            self.touches = touches
            self.viewCenter = viewCenter
        }
    }

    /// What a pan or pinch measures from: the transform and the touches when the current set of
    /// fingers went down.
    public struct CanvasTouchSession: Sendable, Equatable {
        public var start: CanvasTransform
        public var touches: [Int: CanvasPoint]
        public init(start: CanvasTransform, touches: [Int: CanvasPoint]) {
            self.start = start
            self.touches = touches
        }
    }

    public struct CompartmentDragOrigin: Sendable, Equatable {
        public var id: String
        public var x: Double
        public var y: Double
    }

    // MARK: - Action

    public enum Action: Sendable {
        case load(ModelDocument)
        // Selection
        case selectCompartment(String?)
        case selectLink(Int?)
        /// Picks it and opens the inspector on it.
        case editCompartment(String)
        case editLink(Int)
        case setInspectorTab(InspectorTab)
        case setModelTab(ModelTab)
        // Document-level mutations
        case renameDocument(String)
        case updateDescription(String)
        case updateField(ModelField)
        /// The canvas's backdrop for this model; `nil` goes back to its field's.
        case updateBackdrop(EditorBackdrop?)
        case updateHalfLife(Double)
        // Nuclide management
        case addNuclide
        /// The id and the name it starts with ("New Nuclide", in the reader's language).
        case addNuclideWithId(String, name: String)
        case updateNuclideName(id: String, name: String)
        case updateNuclideHalfLife(id: String, halfLife: Double)
        case deleteNuclide(id: String)
        // Compartment mutations
        case setCompartmentNuclide(compartmentId: String, nuclideId: String)
        case addCompartment
        /// The id, its tint and the name it starts with ("New Compartment", in the reader's language).
        case addCompartmentWithId(String, CompartmentTint, name: String)
        case updateCompartmentName(id: String, name: String)
        case updateCompartmentTint(id: String, tint: CompartmentTint)
        case updateCompartmentFollow(id: String, value: Bool)
        case updateCompartmentDispose(id: String, value: Bool)
        case updateCompartmentIntake(id: String, value: Bool)
        case updateCompartmentFraction(id: String, fraction: Double)
        case moveCompartment(id: String, x: Double, y: Double)
        case beginCompartmentDrag(id: String, x: Double, y: Double)
        case endCompartmentDrag
        case deleteCompartment(id: String)
        // Link mutations
        /// Opens the inspector on a new transfer, with whichever ends are already known.
        case beginTransfer(from: String?, to: String?)
        case setTransferFrom(String?)
        case setTransferTo(String?)
        /// Makes the drafted transfer, and opens the inspector on it.
        case createTransfer
        case cancelTransfer
        case updateLinkRate(index: Int, rate: Double)
        /// Text typed into a number field, read by the world's parser in an effect.
        case typeNumber(NumberField, String)
        /// The text as typed, kept while the field is being edited.
        case numberDrafted(NumberField, String)
        /// The number field was left: what it shows is the value again.
        case endNumberEditing
        case deleteLink(index: Int)
        // Canvas
        case setCanvasTransform(offsetX: Double, offsetY: Double, scale: Double)
        case canvasTouchesChanged(CanvasTouches)
        case canvasTouchesEnded
        // Variants
        case addVariant(name: String)
        case deleteVariant(name: String)
        case renameVariant(old: String, new: String)
        case selectEditingVariant(String?)
        case beginVariantRename(String)
        case setVariantRenameDraft(String)
        case commitVariantRename
        case cancelVariantRename
        // Panels
        case setPanel(EditorPanel, isOpen: Bool)
        case toggleKValues
    }

    // MARK: - Environment

    public struct Environment: Sendable {
        public var newId: @Sendable () -> UUID
        /// How numbers are written and read: the world's. Written where the view state is made, and
        /// read in an effect, never in a reducer.
        public var formatDouble: @Sendable (Double, Int) -> String
        public var formatScientific: @Sendable (Double, Int) -> String
        public var formatInteger: @Sendable (Int) -> String
        public var formatSignificant: @Sendable (Double) -> String
        public var parseDouble: @Sendable (String) -> Double?

        public init(
            newId: @escaping @Sendable () -> UUID,
            formatDouble: @escaping @Sendable (Double, Int) -> String,
            formatScientific: @escaping @Sendable (Double, Int) -> String,
            formatInteger: @escaping @Sendable (Int) -> String,
            formatSignificant: @escaping @Sendable (Double) -> String,
            parseDouble: @escaping @Sendable (String) -> Double?
        ) {
            self.newId = newId
            self.formatDouble = formatDouble
            self.formatScientific = formatScientific
            self.formatInteger = formatInteger
            self.formatSignificant = formatSignificant
            self.parseDouble = parseDouble
        }
    }

    // MARK: - ViewModel

        public struct CompartmentRow: Identifiable, Sendable, Equatable {
            public var id: String
            /// The id of the nuclide this compartment belongs to.
            public var nuclideId: String
            public var name: String
            public var tint: CompartmentTint
            public var x: Double
            public var y: Double
            public var isSelected: Bool
            public var follow: Bool
            public var intake: Bool
            public var dispose: Bool
            public var fraction: Double
            /// The fraction as the canvas shows it, and as its field shows it (the draft while it
            /// is being typed): written where the view state is made.
            public var fractionText: String
            public var fractionInputText: String
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
            /// The rate as it is shown, and as its field shows it (the draft while it is being
            /// typed): written where the view state is made.
            public var rateText: String
            public var rateInputText: String
            /// Its number in the list (K3's 3), as it is shown.
            public var ordinalText: String
        }

        /// A summary row for one nuclide in the model.
        public struct NuclideRow: Identifiable, Sendable, Equatable {
            public var id: String
            public var name: String
            public var halfLife: Double
            /// The half-life as it is shown (to two places, and to one in the model list), and as
            /// its field shows it (the draft while it is being typed).
            public var halfLifeText: String
            public var halfLifeShortText: String
            public var halfLifeInputText: String
            public var compartmentCount: Int
            /// True when the model has more than one nuclide (so this one can be deleted).
            public var canDelete: Bool
        }

        public struct ViewState: Sendable, Equatable {
            public var documentName: String = ""
            public var documentDescription: String = ""
            public var field: ModelField = .generic
            /// The document's own backdrop (`nil` for its field's), and the one shown.
            public var backdrop: EditorBackdrop?
            public var resolvedBackdrop: EditorBackdrop = .graphPaper
            public var lingo: FieldLingo = ModelField.generic.lingo
            /// The units numbers are shown and typed in: the field's.
            public var units: WorkingUnits = ModelField.generic.units
            /// Shortcut for the primary nuclide's half-life; kept for the toolbar badge.
            public var halfLife: Double = 0
            public var nuclides: [NuclideRow] = []
            public var compartments: [CompartmentRow] = []
            public var links: [LinkRow] = []
            public var selectedCompartmentId: String?
            public var selectedLinkIndex: Int?
            public var inspectorTab: InspectorTab = .details
            public var modelTab: ModelTab = .document
            public var transferDraft: TransferDraft? = nil
            /// How the panels show, and whether each is open in that way.
            public var layout: EditorLayout = .sheets
            public var isModelListOpen: Bool = false
            public var isInspectorOpen: Bool = false
            public var showKValues: Bool = false
            public var canvasOffsetX: Double = 0
            public var canvasOffsetY: Double = 0
            public var canvasScale: Double = 1
            /// A pinch in progress, relative to the committed layout: scale it by `pinchScale` about
            /// the view's centre, then move it by `pinchOffset`. Identity between pinches.
            public var pinchScale: Double = 1
            public var pinchOffset: CanvasPoint = CanvasPoint(x: 0, y: 0)
            /// Non-nil while a compartment drag is active; holds the canvas position at drag start.
            public var compartmentDragOriginId: String? = nil
            public var compartmentDragOriginX: Double = 0
            public var compartmentDragOriginY: Double = 0
            /// Sorted variant keys for the document (empty = no variants).
            public var variants: [String] = []
            /// Which variant is currently being edited (nil = base model).
            public var editingVariant: String? = nil
            /// The variant key currently being renamed (nil = not renaming).
            public var renamingVariant: String? = nil
            /// Draft name shown in the rename text field.
            public var variantRenameDraft: String = ""

            // MARK: Pre-computed label strings

            /// Structural and completeness issues in the current model.
            public var validationIssues: [CompartmentalModel.ValidationIssue] = []

            /// The screen's appearance, read off the state's traits here, in the projection.
            public var colorScheme: ColorScheme
            /// Each validation issue's text, in step with `validationIssues`, and how many there are.
            public var validationIssueTexts: [LocalizedStringResource] = []
            public var validationIssueCountText: String = ""
        }

        public enum ViewAction: Sendable {
            case selectCompartment(String?)
            case selectLink(Int?)
            case editCompartment(String)
            case editLink(Int)
            case setInspectorTab(InspectorTab)
            case setModelTab(ModelTab)
            case renameDocument(String)
            case updateDescription(String)
            case updateField(ModelField)
            case updateBackdrop(EditorBackdrop?)
            // Nuclide management
            case addNuclide
            case updateNuclideName(id: String, name: String)
            case updateNuclideHalfLife(id: String, halfLife: Double)
            case deleteNuclide(id: String)
            // Compartment mutations
            case addCompartment
            case setCompartmentNuclide(compartmentId: String, nuclideId: String)
            case updateCompartmentName(id: String, name: String)
            case updateCompartmentTint(id: String, tint: CompartmentTint)
            case updateCompartmentFollow(id: String, value: Bool)
            case updateCompartmentDispose(id: String, value: Bool)
            case updateCompartmentIntake(id: String, value: Bool)
            case updateCompartmentFraction(id: String, fraction: Double)
            case moveCompartment(id: String, x: Double, y: Double)
            case beginCompartmentDrag(id: String, x: Double, y: Double)
            case endCompartmentDrag
            case deleteCompartment(id: String)
            case beginTransfer(from: String?, to: String?)
            case setTransferFrom(String?)
            case setTransferTo(String?)
            case createTransfer
            case cancelTransfer
            case updateLinkRate(index: Int, rate: Double)
            case typeNumber(NumberField, String)
            case endNumberEditing
            case deleteLink(index: Int)
            case setCanvasTransform(offsetX: Double, offsetY: Double, scale: Double)
            case canvasTouchesChanged(CanvasTouches)
            case canvasTouchesEnded
            case setPanel(EditorPanel, isOpen: Bool)
            case toggleKValues
            // Variants
            case addVariant(name: String)
            case deleteVariant(name: String)
            case renameVariant(old: String, new: String)
            case selectEditingVariant(String?)
            case beginVariantRename(String)
            case setVariantRenameDraft(String)
            case commitVariantRename
            case cancelVariantRename
        }

    // MARK: - Pan and pinch

    /// The transform `session` measures from, moved by its fingers: the centre between them pans,
    /// their spread around it zooms, and the canvas point that was under the centre stays under it.
    /// One finger only pans.
    public static func canvasTransform(_ session: CanvasTouchSession, _ now: CanvasTouches) -> CanvasTransform {
        let ids = Array(session.touches.keys)
        let before = ids.compactMap { session.touches[$0] }
        let after = ids.compactMap { now.touches[$0] }
        guard !before.isEmpty, before.count == after.count else { return session.start }
        let c0 = centroid(before), c1 = centroid(after)
        let spread0 = spread(before, around: c0), spread1 = spread(after, around: c1)
        let zoom = ids.count >= 2 && spread0 > 0 ? spread1 / spread0 : 1
        let scale = max(0.2, min(5.0, session.start.scale * zoom))
        let z = scale / session.start.scale
        let center = now.viewCenter
        return CanvasTransform(
            offset: CanvasPoint(
                x: c1.x - center.x - (c0.x - center.x - session.start.offset.x) * z,
                y: c1.y - center.y - (c0.y - center.y - session.start.offset.y) * z
            ),
            scale: scale
        )
    }

    static func commitPinchPreview(_ state: inout State) {
        guard let preview = state.canvasPinchPreview else { return }
        state.canvasOffset = preview.offset
        state.canvasScale = preview.scale
        state.canvasPinchPreview = nil
    }

    private static func centroid(_ points: [CanvasPoint]) -> CanvasPoint {
        let n = Double(points.count)
        return CanvasPoint(x: points.reduce(0) { $0 + $1.x } / n, y: points.reduce(0) { $0 + $1.y } / n)
    }

    private static func spread(_ points: [CanvasPoint], around c: CanvasPoint) -> Double {
        points.reduce(0) { $0 + hypot($1.x - c.x, $1.y - c.y) } / Double(points.count)
    }

    // MARK: - Mappings

    public static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewState> { env in { state in
        let doc = state.document
        let editingModel = state.currentModel
        // Stored in days; shown in the field's units.
        let time = doc.field.units.time.iso.get
        let rate = doc.field.units.rate.iso.get
        let canDelete = doc.model.nuclides.count > 1
        let nuclides = doc.model.nuclides.map { n -> NuclideRow in
            let count = editingModel.compartments.filter { $0.nuclideId == n.id }.count
            return NuclideRow(
                id: n.id, name: n.name, halfLife: n.halfLife,
                halfLifeText: env.formatDouble(time(n.halfLife), 2),
                halfLifeShortText: env.formatDouble(time(n.halfLife), 1),
                halfLifeInputText: state.numberDrafts[.halfLife(nuclide: n.id)] ?? env.formatDouble(time(n.halfLife), 4),
                compartmentCount: count, canDelete: canDelete
            )
        }
        let compartments = editingModel.compartments.map { c -> CompartmentRow in
            let vis = doc.visuals[c.id]
            return CompartmentRow(
                id: c.id,
                nuclideId: c.nuclideId,
                name: c.name,
                tint: vis?.tint ?? .steel,
                x: vis?.x ?? 450,
                y: vis?.y ?? 310,
                isSelected: state.selectedCompartmentId == c.id,
                follow: c.follow,
                intake: c.intake,
                dispose: c.dispose,
                fraction: c.fraction,
                fractionText: env.formatDouble(c.fraction, 2),
                fractionInputText: state.numberDrafts[.fraction(compartment: c.id)] ?? env.formatDouble(c.fraction, 6)
            )
        }
        let links = editingModel.connections.enumerated().map { idx, conn -> LinkRow in
            let fromC = editingModel.compartments.first { $0.id == conn.from }
            let toC   = editingModel.compartments.first { $0.id == conn.to }
            return LinkRow(
                id: idx,
                fromId: conn.from,
                fromName: fromC?.name ?? conn.from,
                fromTint: doc.visuals[conn.from]?.tint ?? .steel,
                toId: conn.to,
                toName: toC?.name ?? conn.to,
                toTint: doc.visuals[conn.to]?.tint ?? .steel,
                rate: conn.rate,
                rateText: env.formatScientific(rate(conn.rate), 2),
                rateInputText: state.numberDrafts[.rate(link: idx)] ?? trimmed(env.formatDouble(rate(conn.rate), 12)),
                ordinalText: env.formatInteger(idx + 1)
            )
        }
        let issues = editingModel.validationIssues.filter { issue in
            // missingHalfLife only matters for nuclear models — halfLife=0 is
            // the normal stable/no-decay state for all other fields.
            if case .missingHalfLife = issue { return doc.field == .nuclear }
            return true
        }

        return ViewState(
            documentName: doc.name,
            documentDescription: doc.description,
            field: doc.field,
            backdrop: doc.backdrop,
            resolvedBackdrop: doc.resolvedBackdrop,
            lingo: doc.field.lingo,
            units: doc.field.units,
            halfLife: doc.halfLife,
            nuclides: nuclides,
            compartments: compartments,
            links: links,
            selectedCompartmentId: state.selectedCompartmentId,
            selectedLinkIndex: state.selectedLinkIndex,
            inspectorTab: state.inspectorTab,
            modelTab: state.modelTab,
            transferDraft: state.transferDraft,
            layout: state.layout,
            isModelListOpen: state.isOpen(.modelList),
            isInspectorOpen: state.isOpen(.inspector),
            showKValues: state.showKValues,
            canvasOffsetX: state.canvasOffset.x,
            canvasOffsetY: state.canvasOffset.y,
            canvasScale: state.canvasScale,
            pinchScale: state.canvasPinchPreview.map { $0.scale / state.canvasScale } ?? 1,
            pinchOffset: state.canvasPinchPreview.map {
                CanvasPoint(
                    x: $0.offset.x - state.canvasOffset.x * $0.scale / state.canvasScale,
                    y: $0.offset.y - state.canvasOffset.y * $0.scale / state.canvasScale
                )
            } ?? CanvasPoint(x: 0, y: 0),
            compartmentDragOriginId: state.compartmentDragOrigin?.id,
            compartmentDragOriginX:  state.compartmentDragOrigin?.x ?? 0,
            compartmentDragOriginY:  state.compartmentDragOrigin?.y ?? 0,
            variants:                doc.variants.keys.sorted(),
            editingVariant:          state.editingVariant,
            renamingVariant:         state.renamingVariant,
            variantRenameDraft:      state.variantRenameDraft,
            validationIssues: issues,
            colorScheme: state.traits.isDark ? .dark : .light,
            validationIssueTexts: issues.map { $0.text(env.formatSignificant) },
            validationIssueCountText: env.formatInteger(issues.count)
        )
    } }

    public static let mapAction = Reader<Environment, @Sendable (ViewAction) -> Action> { _ in { va in
        switch va {
        case .selectCompartment(let id):                           .selectCompartment(id)
        case .selectLink(let idx):                                 .selectLink(idx)
        case .editCompartment(let id):                             .editCompartment(id)
        case .editLink(let idx):                                   .editLink(idx)
        case .setInspectorTab(let tab):                            .setInspectorTab(tab)
        case .setModelTab(let tab):                                .setModelTab(tab)
        case .renameDocument(let n):                               .renameDocument(n)
        case .updateDescription(let d):                            .updateDescription(d)
        case .updateField(let f):                                  .updateField(f)
        case .updateBackdrop(let b):                               .updateBackdrop(b)
        case .addNuclide:                                          .addNuclide
        case .updateNuclideName(let id, let n):                    .updateNuclideName(id: id, name: n)
        case .updateNuclideHalfLife(let id, let hl):               .updateNuclideHalfLife(id: id, halfLife: hl)
        case .deleteNuclide(let id):                               .deleteNuclide(id: id)
        case .addCompartment:                                      .addCompartment
        case .setCompartmentNuclide(let cId, let nId):             .setCompartmentNuclide(compartmentId: cId, nuclideId: nId)
        case .updateCompartmentName(let id, let n):                .updateCompartmentName(id: id, name: n)
        case .updateCompartmentTint(let id, let t):                .updateCompartmentTint(id: id, tint: t)
        case .updateCompartmentFollow(let id, let v):              .updateCompartmentFollow(id: id, value: v)
        case .updateCompartmentDispose(let id, let v):             .updateCompartmentDispose(id: id, value: v)
        case .updateCompartmentIntake(let id, let v):              .updateCompartmentIntake(id: id, value: v)
        case .updateCompartmentFraction(let id, let f):            .updateCompartmentFraction(id: id, fraction: f)
        case .moveCompartment(let id, let x, let y):               .moveCompartment(id: id, x: x, y: y)
        case .beginCompartmentDrag(let id, let x, let y):         .beginCompartmentDrag(id: id, x: x, y: y)
        case .endCompartmentDrag:                                  .endCompartmentDrag
        case .deleteCompartment(let id):                           .deleteCompartment(id: id)
        case .beginTransfer(let from, let to):                     .beginTransfer(from: from, to: to)
        case .setTransferFrom(let id):                             .setTransferFrom(id)
        case .setTransferTo(let id):                               .setTransferTo(id)
        case .createTransfer:                                      .createTransfer
        case .cancelTransfer:                                      .cancelTransfer
        case .updateLinkRate(let idx, let r):                      .updateLinkRate(index: idx, rate: r)
        case .typeNumber(let field, let text):                     .typeNumber(field, text)
        case .endNumberEditing:                                    .endNumberEditing
        case .deleteLink(let idx):                                 .deleteLink(index: idx)
        case .setCanvasTransform(let ox, let oy, let s):           .setCanvasTransform(offsetX: ox, offsetY: oy, scale: s)
        case .canvasTouchesChanged(let t):                       .canvasTouchesChanged(t)
        case .canvasTouchesEnded:                                  .canvasTouchesEnded
        case .setPanel(let panel, let isOpen):                     .setPanel(panel, isOpen: isOpen)
        case .toggleKValues:                                       .toggleKValues
        case .addVariant(let n):                                   .addVariant(name: n)
        case .deleteVariant(let n):                                .deleteVariant(name: n)
        case .renameVariant(let o, let n):                         .renameVariant(old: o, new: n)
        case .selectEditingVariant(let k):                         .selectEditingVariant(k)
        case .beginVariantRename(let k):                           .beginVariantRename(k)
        case .setVariantRenameDraft(let s):                        .setVariantRenameDraft(s)
        case .commitVariantRename:                                 .commitVariantRename
        case .cancelVariantRename:                                 .cancelVariantRename
        }
    } }

    // MARK: - Lifecycle

    public static func initialState(with _: Void) -> State { .init() }

    public static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, context in
            switch action {
            case .load(let doc):
                .reduce {
                    $0.document = doc
                    $0.selectedCompartmentId = nil
                    $0.selectedLinkIndex = nil
                    $0.transferDraft = nil
                    $0.canvasOffset = CanvasPoint(x: 0, y: 0)
                    $0.canvasScale = 1.0
                }

            case .selectCompartment(let id):
                // Picking only picks: editing is asked for (Edit), so nothing opens over the canvas.
                .reduce {
                    $0.selectedCompartmentId = id
                    $0.selectedLinkIndex = nil
                }

            case .selectLink(let idx):
                .reduce {
                    $0.selectedLinkIndex = idx
                    $0.selectedCompartmentId = nil
                }

            case .editCompartment(let id):
                .reduce {
                    $0.selectedCompartmentId = id
                    $0.selectedLinkIndex = nil
                    $0.transferDraft = nil
                    $0.setPanel(.inspector, true)
                }

            case .editLink(let idx):
                .reduce {
                    $0.selectedLinkIndex = idx
                    $0.selectedCompartmentId = nil
                    $0.transferDraft = nil
                    $0.setPanel(.inspector, true)
                }

            case .setInspectorTab(let tab):
                .reduce { $0.inspectorTab = tab }

            case .setModelTab(let tab):
                .reduce { $0.modelTab = tab }

            case .renameDocument(let name):
                .reduce { $0.document.name = name }

            case .updateDescription(let desc):
                .reduce { $0.document.description = desc }

            case .updateField(let f):
                .reduce { $0.document.field = f }

            case .updateBackdrop(let backdrop):
                .reduce { $0.document.backdrop = backdrop }

            case .updateHalfLife(let hl):
                .reduce { state in
                    guard let first = state.document.model.nuclides.first else { return }
                    let updated = Nuclide(id: first.id, name: first.name, halfLife: max(0, hl))
                    let rest = Array(state.document.model.nuclides.dropFirst())
                    state.document.model = state.document.model.with(nuclides: [updated] + rest)
                }

            case .addNuclide:
                // Named in an effect: the reader's language is read here, never in a reducer.
                .produce { [field = (context.stateBefore ?? State()).document.field] ctx in .just(.addNuclideWithId(
                    ctx.environment.newId().uuidString.prefix(8).lowercased().description,
                    name: String(localized: L.Resource.Editor.newSubstance(L.domainString(field.lingo.substanceName))))) }

            case .addNuclideWithId(let id, let name):
                .reduce { state in
                    let nuclide = Nuclide(id: id, name: name, halfLife: 0)
                    state.document.model = state.document.model.with(
                        nuclides: state.document.model.nuclides + [nuclide]
                    )
                }

            case .updateNuclideName(let id, let name):
                .reduce { state in
                    state.document.model = state.document.model.with(
                        nuclides: state.document.model.nuclides.map {
                            $0.id == id ? Nuclide(id: $0.id, name: name, halfLife: $0.halfLife) : $0
                        }
                    )
                    state.syncNuclidesToVariants()
                }

            case .updateNuclideHalfLife(let id, let hl):
                .reduce { state in
                    state.document.model = state.document.model.with(
                        nuclides: state.document.model.nuclides.map {
                            $0.id == id ? Nuclide(id: $0.id, name: $0.name, halfLife: max(0, hl)) : $0
                        }
                    )
                    state.syncNuclidesToVariants()
                }

            case .deleteNuclide(let id):
                .reduce { state in
                    guard state.document.model.nuclides.count > 1 else { return }
                    let remaining = state.document.model.nuclides.filter { $0.id != id }
                    let fallbackId = remaining.first?.id ?? "n0"
                    state.document.model = CompartmentalModel(
                        nuclides: remaining,
                        compartments: state.document.model.compartments.map {
                            $0.nuclideId == id ? $0.with(nuclideId: fallbackId) : $0
                        },
                        connections: state.document.model.connections
                    )
                    state.syncNuclidesToVariants()
                }

            case .setCompartmentNuclide(let compartmentId, let nuclideId):
                .reduce { state in
                    guard state.currentModel.nuclides.contains(where: { $0.id == nuclideId }) else { return }
                    state.setCurrentModel(state.currentModel.updatingCompartment(id: compartmentId) {
                        $0.with(nuclideId: nuclideId)
                    })
                }

            case .addCompartment:
                // The next colour round the palette, so a few new ones in a row can be told apart;
                // it can be changed in the inspector.
                .produce { [count = (context.stateBefore ?? State()).currentModel.compartments.count] ctx in .just(.addCompartmentWithId(
                    ctx.environment.newId().uuidString.prefix(8).lowercased().description,
                    CompartmentTint.allCases[count % CompartmentTint.allCases.count],
                    name: String(localized: L.Resource.Editor.newCompartment)
                )) }

            case .addCompartmentWithId(let idStr, let tint, let name):
                .reduce { state in
                    let nuclideId = state.currentModel.nuclides.first?.id ?? "n0"
                    let compartment = Compartment(
                        id: idStr, nuclideId: nuclideId, name: name,
                        follow: false, intake: false, dispose: false, fraction: 0
                    )
                    state.setCurrentModel(state.currentModel.with(
                        compartments: state.currentModel.compartments + [compartment]
                    ))
                    state.document.visuals[idStr] = CompartmentVisuals(x: 450, y: 310, tint: tint)
                    state.selectedCompartmentId = idStr
                    state.selectedLinkIndex = nil
                    state.transferDraft = nil
                    state.setPanel(.inspector, true)
                    state.inspectorTab = .details
                }

            case .updateCompartmentName(let id, let name):
                .reduce { state in
                    state.setCurrentModel(state.currentModel.updatingCompartment(id: id) {
                        $0.with(name: name)
                    })
                }

            case .updateCompartmentTint(let id, let tint):
                .reduce { $0.document.visuals[id]?.tint = tint }

            case .updateCompartmentFollow(let id, let value):
                .reduce { state in
                    state.setCurrentModel(state.currentModel.updatingCompartment(id: id) {
                        $0.with(follow: value)
                    })
                }

            case .updateCompartmentDispose(let id, let value):
                .reduce { state in
                    state.setCurrentModel(state.currentModel.updatingCompartment(id: id) {
                        $0.with(dispose: value)
                    })
                }

            case .updateCompartmentIntake(let id, let value):
                .reduce { state in
                    state.setCurrentModel(state.currentModel.updatingCompartment(id: id) {
                        $0.with(intake: value).with(fraction: 0)
                    })
                    let intakeIds = state.currentModel.compartments.filter(\.intake).map(\.id)
                    let equalFraction = intakeIds.isEmpty ? 0.0 : 1.0 / Double(intakeIds.count)
                    for iid in intakeIds {
                        state.setCurrentModel(state.currentModel.updatingCompartment(id: iid) {
                            $0.with(fraction: equalFraction)
                        })
                    }
                }

            case .updateCompartmentFraction(let id, let fraction):
                .reduce { state in
                    state.setCurrentModel(state.currentModel.updatingCompartment(id: id) {
                        $0.with(fraction: max(0, min(1, fraction)))
                    })
                }

            case .beginCompartmentDrag(let id, let x, let y):
                .reduce { $0.compartmentDragOrigin = CompartmentDragOrigin(id: id, x: x, y: y) }

            case .endCompartmentDrag:
                .reduce { $0.compartmentDragOrigin = nil }

            case .moveCompartment(let id, let x, let y):
                .reduce { state in
                    if var vis = state.document.visuals[id] {
                        vis.x = x; vis.y = y
                        state.document.visuals[id] = vis
                    }
                }

            case .deleteCompartment(let id):
                .reduce { state in
                    state.setCurrentModel(state.currentModel.with(
                        compartments: state.currentModel.compartments.filter { $0.id != id },
                        connections: state.currentModel.connections.filter {
                            $0.from != id && $0.to != id
                        }
                    ))
                    state.document.visuals.removeValue(forKey: id)
                    if state.selectedCompartmentId == id { state.selectedCompartmentId = nil }
                    if state.transferDraft?.from == id { state.transferDraft?.from = nil }
                    if state.transferDraft?.to == id { state.transferDraft?.to = nil }
                }

            case .beginTransfer(let from, let to):
                .reduce { state in
                    state.transferDraft = TransferDraft(from: from, to: to)
                    state.setPanel(.inspector, true)
                }

            case .setTransferFrom(let id):
                .reduce { $0.transferDraft?.from = id }

            case .setTransferTo(let id):
                .reduce { $0.transferDraft?.to = id }

            case .createTransfer:
                .reduce { state in
                    guard let draft = state.transferDraft, draft.isComplete, let from = draft.from, let to = draft.to else { return }
                    let conn = CompartmentConnection(from: from, to: to, rate: 0.1)
                    state.setCurrentModel(state.currentModel.with(
                        connections: state.currentModel.connections + [conn]
                    ))
                    state.selectedLinkIndex = state.currentModel.connections.count - 1
                    state.selectedCompartmentId = nil
                    state.transferDraft = nil
                    state.inspectorTab = .details
                }

            case .cancelTransfer:
                .reduce { $0.transferDraft = nil }

            case .typeNumber(let field, let text):
                typeNumberReaction(field, text, context: context)

            case .numberDrafted(let field, let text):
                .reduce { $0.numberDrafts[field] = text }

            case .endNumberEditing:
                .reduce { $0.numberDrafts = [:] }

            case .updateLinkRate(let idx, let rate):
                .reduce { state in
                    guard idx < state.currentModel.connections.count else { return }
                    let old = state.currentModel.connections[idx]
                    var conns = state.currentModel.connections
                    conns[idx] = CompartmentConnection(from: old.from, to: old.to, rate: rate)
                    state.setCurrentModel(state.currentModel.with(connections: conns))
                }

            case .deleteLink(let idx):
                .reduce { state in
                    guard idx < state.currentModel.connections.count else { return }
                    var conns = state.currentModel.connections
                    conns.remove(at: idx)
                    state.setCurrentModel(state.currentModel.with(connections: conns))
                    if state.selectedLinkIndex == idx { state.selectedLinkIndex = nil }
                }

            case .setCanvasTransform(let ox, let oy, let scale):
                .reduce { state in
                    state.canvasOffset = CanvasPoint(x: ox, y: oy)
                    state.canvasScale = max(0.2, min(5.0, scale))
                }

            case .canvasTouchesChanged(let now):
                // From the reducer's own state, not the view's last render. A finger added or
                // lifted commits any preview and starts a new session from there: no jump.
                .reduce { state in
                    guard let session = state.canvasTouchSession, Set(session.touches.keys) == Set(now.touches.keys) else {
                        Self.commitPinchPreview(&state)
                        let start = CanvasTransform(offset: state.canvasOffset, scale: state.canvasScale)
                        state.canvasTouchSession = now.touches.isEmpty ? nil : CanvasTouchSession(start: start, touches: now.touches)
                        return
                    }
                    let transform = Self.canvasTransform(session, now)
                    if session.touches.count >= 2 {
                        state.canvasPinchPreview = transform
                    } else {
                        state.canvasOffset = transform.offset
                        state.canvasScale = transform.scale
                    }
                }

            case .canvasTouchesEnded:
                .reduce { state in
                    Self.commitPinchPreview(&state)
                    state.canvasTouchSession = nil
                }

            case .setPanel(let panel, let isOpen):
                .reduce { $0.setPanel(panel, isOpen) }

            case .toggleKValues:
                .reduce { $0.showKValues.toggle() }

            case .addVariant(let name):
                .reduce { state in
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
                          state.document.variants[name] == nil else { return }
                    state.document.variants[name] = state.currentModel
                    state.editingVariant = name
                }

            case .deleteVariant(let name):
                .reduce { state in
                    state.document.variants.removeValue(forKey: name)
                    if state.editingVariant == name { state.editingVariant = nil }
                }

            case .renameVariant(let old, let new):
                .reduce { state in
                    guard let model = state.document.variants[old],
                          !new.trimmingCharacters(in: .whitespaces).isEmpty,
                          state.document.variants[new] == nil else { return }
                    state.document.variants.removeValue(forKey: old)
                    state.document.variants[new] = model
                    if state.editingVariant == old { state.editingVariant = new }
                }

            case .selectEditingVariant(let key):
                .reduce { state in
                    guard key == nil || state.document.variants[key!] != nil else { return }
                    state.editingVariant = key
                    state.selectedCompartmentId = nil
                    state.selectedLinkIndex = nil
                }

            case .beginVariantRename(let key):
                .reduce { state in
                    guard state.document.variants[key] != nil else { return }
                    state.renamingVariant = key
                    state.variantRenameDraft = key
                }

            case .setVariantRenameDraft(let draft):
                .reduce { $0.variantRenameDraft = draft }

            case .commitVariantRename:
                .reduce { state in
                    guard let old = state.renamingVariant else { return }
                    let new = state.variantRenameDraft.trimmingCharacters(in: .whitespaces)
                    guard !new.isEmpty, new != old, state.document.variants[new] == nil,
                          let model = state.document.variants[old] else {
                        state.renamingVariant = nil
                        return
                    }
                    state.document.variants.removeValue(forKey: old)
                    state.document.variants[new] = model
                    if state.editingVariant == old { state.editingVariant = new }
                    state.renamingVariant = nil
                }

            case .cancelVariantRename:
                .reduce { $0.renamingVariant = nil }
            }
        }
    }

    /// A number typed into a field: read where the world's parser runs, never in a reducer. The
    /// draft is kept as typed; the value follows only text that reads as a number, taken in the
    /// field's units and stored in the canonical ones.
    @MainActor
    private static func typeNumberReaction(
        _ field: NumberField,
        _ text: String,
        context: PreReducerContext<State>
    ) -> Reaction<Action, State, Environment> {
        let units = (context.stateBefore ?? State()).document.field.units
        return .produce { ctx in
            let value = ctx.environment.parseDouble(text.trimmingCharacters(in: .whitespaces))
            return .sequence([.numberDrafted(field, text)] + (value.map { [field.update($0, in: units)] } ?? []))
        }
    }

    public typealias Content = EditorView
}

extension EditorFeature {
    /// A number field in the editor: whose number it is.
    public enum NumberField: Hashable, Sendable {
        case halfLife(nuclide: String)
        case fraction(compartment: String)
        case rate(link: Int)

        /// The edit that sets this field's number to `value`, typed in `units`: the document gets
        /// it in the canonical unit.
        func update(_ value: Double, in units: WorkingUnits) -> Action {
            switch self {
            case let .halfLife(id): .updateNuclideHalfLife(id: id, halfLife: units.time.iso.reverseGet(value))
            case let .fraction(id): .updateCompartmentFraction(id: id, fraction: value)
            case let .rate(index): .updateLinkRate(index: index, rate: units.rate.iso.reverseGet(value))
            }
        }
    }
}

/// A number as written, without the zeros a fixed number of places leaves at its end:
/// "0,500000" → "0,5", "2.000000" → "2". Text, not a number: the separator is whichever the
/// writer used.
private func trimmed(_ written: String) -> String {
    guard written.contains(where: { $0 == "." || $0 == "," }) else { return written }
    let withoutZeros = written.reversed().drop { $0 == "0" }
    return String(withoutZeros.drop { $0 == "." || $0 == "," }.reversed())
}
