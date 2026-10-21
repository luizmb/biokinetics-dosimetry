import AppDomain
import Domain
import SwiftRexArchitecture
import SwiftUI
import Localization
import Vitral

// MARK: - EditorView (container)

@BoundTo(EditorFeature.self)
public struct EditorView: View {
    public var body: some View {
        // All bidirectional field bindings are created here, once, in the container.
        // Each binding's `get` re-reads from the viewModel so it always returns the latest value.

        let modelListBinding = Binding(
            get: { viewStore.state.isModelListOpen },
            set: { viewStore.dispatch(.setPanel(.modelList, isOpen: $0)) }
        )

        let inspectorBinding = Binding(
            get: { viewStore.state.isInspectorOpen },
            set: { viewStore.dispatch(.setPanel(.inspector, isOpen: $0)) }
        )

        let inspectorTabBinding = Binding(
            get: { viewStore.state.inspectorTab.value },
            set: { viewStore.dispatch(.setInspectorTab($0)) }
        )

        let modelTabBinding = Binding(
            get: { viewStore.state.modelTab.value },
            set: { viewStore.dispatch(.setModelTab($0)) }
        )

        let showKValuesBinding = Binding(
            get: { viewStore.state.showKValues },
            set: { if $0 != viewStore.state.showKValues { viewStore.dispatch(.toggleKValues) } }
        )

        // Compartment field bindings — nil when no compartment is selected.
        let compBindings: CompartmentFieldBindings? = viewStore.state.selectedCompartmentId.flatMap { id in
            guard viewStore.state.compartments.value.contains(where: { $0.id == id }) else { return nil }
            let isMultiNuclide = viewStore.state.nuclides.value.count > 1
            return CompartmentFieldBindings(  // isMultiNuclide used to guard dispatch below
                name: Binding(
                    get: { viewStore.state.compartments.value.first { $0.id == id }?.name ?? "" },
                    set: { viewStore.dispatch(.updateCompartmentName(id: id, name: $0)) }
                ),
                tint: Binding(
                    get: { viewStore.state.compartments.value.first { $0.id == id }?.tint ?? .steel },
                    set: { viewStore.dispatch(.updateCompartmentTint(id: id, tint: $0)) }
                ),
                follow: Binding(
                    get: { viewStore.state.compartments.value.first { $0.id == id }?.follow ?? false },
                    set: { viewStore.dispatch(.updateCompartmentFollow(id: id, value: $0)) }
                ),
                dispose: Binding(
                    get: { viewStore.state.compartments.value.first { $0.id == id }?.dispose ?? false },
                    set: { viewStore.dispatch(.updateCompartmentDispose(id: id, value: $0)) }
                ),
                intake: Binding(
                    get: { viewStore.state.compartments.value.first { $0.id == id }?.intake ?? false },
                    set: { viewStore.dispatch(.updateCompartmentIntake(id: id, value: $0)) }
                ),
                fractionText: Binding(
                    get: { viewStore.state.compartments.value.first { $0.id == id }?.fractionInputText ?? "" },
                    set: { viewStore.dispatch(.typeNumber(.fraction(compartment: id), $0)) }
                ),
                nuclideId: Binding(
                    get: { viewStore.state.compartments.value.first { $0.id == id }?.nuclideId ?? "" },
                    set: { if isMultiNuclide { viewStore.dispatch(.setCompartmentNuclide(compartmentId: id, nuclideId: $0)) } }
                )
            )
        }

        // Link field bindings — nil when no link is selected.
        let linkBindings: LinkFieldBindings? = viewStore.state.selectedLinkIndex.flatMap { idx in
            guard viewStore.state.links.value.contains(where: { $0.id == idx }) else { return nil }
            return LinkFieldBindings(
                rateText: Binding(
                    get: { viewStore.state.links.value.first { $0.id == idx }?.rateInputText ?? "" },
                    set: { viewStore.dispatch(.typeNumber(.rate(link: idx), $0)) }
                )
            )
        }

        let documentNameBinding = Binding(
            get: { viewStore.state.documentName },
            set: { viewStore.dispatch(.renameDocument($0)) }
        )

        let documentDescriptionBinding = Binding(
            get: { viewStore.state.documentDescription },
            set: { viewStore.dispatch(.updateDescription($0)) }
        )

        let fieldBinding = Binding(
            get: { viewStore.state.field.value },
            set: { viewStore.dispatch(.updateField($0)) }
        )

        let backdropBinding = Binding(
            get: { viewStore.state.backdrop.value },
            set: { viewStore.dispatch(.updateBackdrop($0)) }
        )

        // Nuclide field bindings — one entry per nuclide in the document.
        let nuclideBindings: [NuclideEditBinding] = viewStore.state.nuclides.value.map { n in
            NuclideEditBinding(
                id: n.id,
                name: Binding(
                    get: { viewStore.state.nuclides.value.first { $0.id == n.id }?.name ?? "" },
                    set: { viewStore.dispatch(.updateNuclideName(id: n.id, name: $0)) }
                ),
                halfLife: Binding(
                    get: { viewStore.state.nuclides.value.first { $0.id == n.id }?.halfLife ?? 0 },
                    set: { viewStore.dispatch(.updateNuclideHalfLife(id: n.id, halfLife: $0)) }
                ),
                halfLifeText: Binding(
                    get: { viewStore.state.nuclides.value.first { $0.id == n.id }?.halfLifeInputText ?? "" },
                    set: { viewStore.dispatch(.typeNumber(.halfLife(nuclide: n.id), $0)) }
                ),
                canDelete: n.canDelete,
                compartmentCount: n.compartmentCount
            )
        }

        return EditorContent(
            documentName: documentNameBinding,
            documentDescription: documentDescriptionBinding,
            field: fieldBinding,
            backdrop: backdropBinding,
            resolvedBackdrop: viewStore.state.resolvedBackdrop.value,
            lingo: viewStore.state.lingo.value,
            units: viewStore.state.units.value,
            halfLife: viewStore.state.halfLife,
            nuclides: viewStore.state.nuclides.value,
            compartments: viewStore.state.compartments.value,
            links: viewStore.state.links.value,
            selectedCompartmentId: viewStore.state.selectedCompartmentId,
            selectedLinkIndex: viewStore.state.selectedLinkIndex,
            inspectorTab: inspectorTabBinding,
            modelTab: modelTabBinding,
            transferDraft: viewStore.state.transferDraft.value,
            compartmentBindings: compBindings,
            linkBindings: linkBindings,
            nuclideBindings: nuclideBindings,
            layout: viewStore.state.layout.value,
            isModelListOpen: modelListBinding,
            isInspectorOpen: inspectorBinding,
            showKValues: showKValuesBinding,
            validationIssues: viewStore.state.validationIssues.value,
            canvasOffsetX: viewStore.state.canvasOffsetX,
            canvasOffsetY: viewStore.state.canvasOffsetY,
            canvasScale: viewStore.state.canvasScale,
            pinchScale: viewStore.state.pinchScale,
            pinchOffset: viewStore.state.pinchOffset.value,
            compartmentDragOriginId: viewStore.state.compartmentDragOriginId,
            compartmentDragOriginX: viewStore.state.compartmentDragOriginX,
            compartmentDragOriginY: viewStore.state.compartmentDragOriginY,
            variants: viewStore.state.variants.value,
            editingVariant: viewStore.state.editingVariant,
            renamingVariant: viewStore.state.renamingVariant,
            variantRenameDraft: viewStore.binding(.state(\.variantRenameDraft).action(\.setVariantRenameDraft)),
            onSelectCompartment: { viewStore.dispatch(.selectCompartment($0)) },
            onSelectLink: { viewStore.dispatch(.selectLink($0)) },
            onEditCompartment: { viewStore.dispatch(.editCompartment($0)) },
            onEditLink: { viewStore.dispatch(.editLink($0)) },
            onBeginTransfer: { viewStore.dispatch(.beginTransfer(from: $0, to: $1)) },
            onSetTransferFrom: { viewStore.dispatch(.setTransferFrom($0)) },
            onSetTransferTo: { viewStore.dispatch(.setTransferTo($0)) },
            onCreateTransfer: { viewStore.dispatch(.createTransfer) },
            onCancelTransfer: { viewStore.dispatch(.cancelTransfer) },
            onAddCompartment: { viewStore.dispatch(.addCompartment) },
            onDeleteCompartment: { viewStore.dispatch(.deleteCompartment(id: $0)) },
            onDeleteLink: { viewStore.dispatch(.deleteLink(index: $0)) },
            onMoveCompartment: { viewStore.dispatch(.moveCompartment(id: $0, x: $1, y: $2)) },
            onBeginCompartmentDrag: { viewStore.dispatch(.beginCompartmentDrag(id: $0, x: $1, y: $2)) },
            onEndCompartmentDrag: { viewStore.dispatch(.endCompartmentDrag) },
            onCanvasTouches: { viewStore.dispatch(.canvasTouchesChanged($0)) },
            onEndCanvasTouches: { viewStore.dispatch(.canvasTouchesEnded) },
            onSetCanvasTransform: { viewStore.dispatch(.setCanvasTransform(offsetX: $0, offsetY: $1, scale: $2)) },
            onAddNuclide: { viewStore.dispatch(.addNuclide) },
            onDeleteNuclide: { viewStore.dispatch(.deleteNuclide(id: $0)) },
            onAddVariant: { viewStore.dispatch(.addVariant(name: $0)) },
            onDeleteVariant: { viewStore.dispatch(.deleteVariant(name: $0)) },
            onSelectEditingVariant: { viewStore.dispatch(.selectEditingVariant($0)) },
            onBeginVariantRename: { viewStore.dispatch(.beginVariantRename($0)) },
            onCommitVariantRename: { viewStore.dispatch(.commitVariantRename) },
            onCancelVariantRename: { viewStore.dispatch(.cancelVariantRename) },
            colorScheme: viewStore.state.colorScheme.value,
            validationIssueTexts: viewStore.state.validationIssueTexts.value,
            validationIssueCountText: viewStore.state.validationIssueCountText,
            onEndNumberEditing: { viewStore.dispatch(.endNumberEditing) }
        )
        .inlineNavigationTitle()
    }
}

// MARK: - EditorContent (pure view)

struct EditorContent: View {
    // MARK: Read-only view state
    var documentName: Binding<String>
    var documentDescription: Binding<String>
    var field: Binding<ModelField>
    /// The model's own backdrop (`nil` for its field's), and the one shown.
    var backdrop: Binding<EditorBackdrop?>
    let resolvedBackdrop: EditorBackdrop
    let lingo: FieldLingo
    let units: WorkingUnits
    let halfLife: Double
    let nuclides: [EditorFeature.NuclideRow]
    let compartments: [EditorFeature.CompartmentRow]
    let links: [EditorFeature.LinkRow]
    let selectedCompartmentId: String?
    let selectedLinkIndex: Int?

    // MARK: Bidirectional bindings (created by the container)
    var inspectorTab: Binding<EditorFeature.InspectorTab>
    var modelTab: Binding<EditorFeature.ModelTab>
    let transferDraft: EditorFeature.TransferDraft?
    var compartmentBindings: CompartmentFieldBindings?
    var linkBindings: LinkFieldBindings?
    var nuclideBindings: [NuclideEditBinding]

    // MARK: Panels
    /// How the panels show: from the view state, which reads it off the screen's traits.
    let layout: EditorFeature.EditorLayout
    var isModelListOpen: Binding<Bool>
    var isInspectorOpen: Binding<Bool>

    // MARK: Read-only display state
    var showKValues: Binding<Bool>
    let validationIssues: [CompartmentalModel.ValidationIssue]
    let canvasOffsetX: Double
    let canvasOffsetY: Double
    let canvasScale: Double
    let pinchScale: Double
    let pinchOffset: EditorFeature.CanvasPoint
    let compartmentDragOriginId: String?
    let compartmentDragOriginX: Double
    let compartmentDragOriginY: Double
    let variants: [String]
    let editingVariant: String?
    let renamingVariant: String?
    var variantRenameDraft: Binding<String>

    // MARK: One-way action callbacks
    var onSelectCompartment: (String?) -> Void
    var onSelectLink: (Int?) -> Void
    var onEditCompartment: (String) -> Void
    var onEditLink: (Int) -> Void
    var onBeginTransfer: (String?, String?) -> Void
    var onSetTransferFrom: (String?) -> Void
    var onSetTransferTo: (String?) -> Void
    var onCreateTransfer: () -> Void
    var onCancelTransfer: () -> Void
    var onAddCompartment: () -> Void
    var onDeleteCompartment: (String) -> Void
    var onDeleteLink: (Int) -> Void
    var onMoveCompartment: (String, Double, Double) -> Void
    var onBeginCompartmentDrag: (String, Double, Double) -> Void
    var onEndCompartmentDrag: () -> Void
    var onCanvasTouches: (EditorFeature.CanvasTouches) -> Void
    var onEndCanvasTouches: () -> Void
    var onSetCanvasTransform: (Double, Double, Double) -> Void
    var onAddNuclide: () -> Void
    var onDeleteNuclide: (String) -> Void
    var onAddVariant: (String) -> Void
    var onDeleteVariant: (String) -> Void
    var onSelectEditingVariant: (String?) -> Void
    var onBeginVariantRename: (String) -> Void
    var onCommitVariantRename: () -> Void
    var onCancelVariantRename: () -> Void

    /// The screen's appearance, from the view state.
    let colorScheme: ColorScheme
    /// Each issue's text, in step with `validationIssues`, and how many there are: written where
    /// the view state is made.
    let validationIssueTexts: [LocalizedStringResource]
    let validationIssueCountText: String
    /// A number field was left: what it shows is the value again.
    var onEndNumberEditing: () -> Void

    var body: some View {
        ZStack {
            // Graph paper is the canvas's own, sliding with it; any other backdrop sits behind.
            if resolvedBackdrop != .graphPaper { Backdrop(resolvedBackdrop.style) } else { Backdrop() }
            // The panels as the screen allows: beside the canvas on a pad, over it one at a time on
            // a phone on its side, in a sheet on a phone held upright. Told, never measured.
            Workspace(mode: layout.workspaceMode, exclusive: layout != .docked, closeLabel: L.Common.close) {
                canvasArea
            }
            .leading(isPresented: isModelListOpen) { modelList }
            .trailing(isPresented: isInspectorOpen) { inspector }
        }
        .navigationTitle(documentName.wrappedValue)
        .toolbar { toolbarItems }
        .workspaceToolbar(
            leading: (isPresented: isModelListOpen, label: L.Common.model),
            trailing: (isPresented: isInspectorOpen, label: L.Common.inspector)
        )
    }

    // MARK: - Canvas area

    private var canvasArea: some View {
        ZStack(alignment: .top) {
            // Edge to edge: the navigation bar is glass over the canvas, not a bar over a flat
            // background.
            canvas
                .ignoresSafeArea()
            // A soft fade where the canvas runs under the navigation bar and the home indicator.
            EdgeFade(.top)
            EdgeFade(.bottom)
        }
    }

    private var canvas: some View {
        CompartmentCanvasView(
            compartments: compartments, links: links,
            drawsGraphPaper: resolvedBackdrop == .graphPaper,
            selectedCompartmentId: selectedCompartmentId,
            selectedLinkIndex: selectedLinkIndex,
            showKValues: showKValues.wrappedValue,
            canvasOffsetX: canvasOffsetX, canvasOffsetY: canvasOffsetY,
            canvasScale: canvasScale,
            pinchScale: pinchScale,
            pinchOffset: pinchOffset,
            compartmentDragOriginId: compartmentDragOriginId,
            compartmentDragOriginX: compartmentDragOriginX,
            compartmentDragOriginY: compartmentDragOriginY,
            onSelectCompartment: onSelectCompartment,
            onSelectLink: onSelectLink,
            onMoveCompartment: onMoveCompartment,
            onBeginCompartmentDrag: onBeginCompartmentDrag,
            onEndCompartmentDrag: onEndCompartmentDrag,
            onCanvasTouches: onCanvasTouches,
            onEndCanvasTouches: onEndCanvasTouches,
            onSetCanvasTransform: onSetCanvasTransform, colorScheme: colorScheme
        )
    }

    // MARK: - Panels

    /// The document's settings, and what the model is made of: two pages, one panel.
    private var modelList: some View {
        SegmentedPages(selection: modelTab, showsTitles: true) { tab in
            switch tab {
            case .document: documentPage
            case .contents: contentsPage
            }
        }
    }

    private var documentPage: some View {
        EditorDocumentPage(
            documentName: documentName,
            documentDescription: documentDescription,
            field: field,
            backdrop: backdrop,
            showKValues: showKValues,
            lingo: lingo,
            units: units,
            nuclideBindings: nuclideBindings,
            validationIssues: validationIssues,
            validationIssueTexts: validationIssueTexts,
            onAddNuclide: onAddNuclide,
            onDeleteNuclide: onDeleteNuclide,
            onAddVariant: onAddVariant,
            onDeleteVariant: onDeleteVariant,
            onSelectEditingVariant: onSelectEditingVariant,
            onBeginVariantRename: onBeginVariantRename,
            onCommitVariantRename: onCommitVariantRename,
            onCancelVariantRename: onCancelVariantRename,
            variants: variants,
            editingVariant: editingVariant,
            renamingVariant: renamingVariant,
            variantRenameDraft: variantRenameDraft,
            colorScheme: colorScheme,
            onEndNumberEditing: onEndNumberEditing
        )
    }

    private var contentsPage: some View {
        EditorModelListPanel(
            lingo: lingo, units: units, nuclides: nuclides, compartments: compartments, links: links,
            selectedCompartmentId: selectedCompartmentId,
            selectedLinkIndex: selectedLinkIndex,
            onSelectCompartment: onSelectCompartment,
            onSelectLink: onSelectLink,
            onEditCompartment: onEditCompartment,
            onEditLink: onEditLink,
            onDeleteCompartment: onDeleteCompartment,
            onDeleteLink: onDeleteLink,
            onAddCompartment: onAddCompartment,
            onAddTransfer: { onBeginTransfer(nil, nil) },
            colorScheme: colorScheme
        )
    }

    private var inspector: some View {
        EditorInspectorPanel(
            lingo: lingo,
            units: units,
            nuclides: nuclides,
            compartments: compartments,
            links: links,
            selectedCompartmentId: selectedCompartmentId,
            selectedLinkIndex: selectedLinkIndex,
            transferDraft: transferDraft,
            inspectorTab: inspectorTab,
            compartmentBindings: compartmentBindings,
            linkBindings: linkBindings,
            onEditCompartment: onEditCompartment,
            onEditLink: onEditLink,
            onBeginTransfer: onBeginTransfer,
            onSetTransferFrom: onSetTransferFrom,
            onSetTransferTo: onSetTransferTo,
            onCreateTransfer: onCreateTransfer,
            onCancelTransfer: onCancelTransfer,
            onDeleteSelected: deleteSelected,
            colorScheme: colorScheme,
            onEndNumberEditing: onEndNumberEditing
        )
    }

    private func deleteSelected() {
        if let id = selectedCompartmentId {
            onDeleteCompartment(id)
        } else if let idx = selectedLinkIndex {
            onDeleteLink(idx)
        }
    }

    // MARK: - Toolbar items

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .platformNavigationLeading) {
            if !validationIssues.isEmpty {
                let errorCount = validationIssues.filter { $0.severity == .error }.count
                let tint: Color = errorCount > 0 ? .orange : .yellow
                Label { Text(verbatim: validationIssueCountText) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(tint.opacity(0.12), in: Capsule())
            }
        }
    }
}

extension EditorFeature.EditorLayout {
    /// The workspace's way of showing the same thing.
    var workspaceMode: WorkspaceMode {
        switch self {
        case .docked: .docked
        case .floating: .floating
        case .sheets: .sheet
        }
    }
}

/// The model panel's pages, as their segments show them.
extension EditorFeature.ModelTab: PageKind {
    public var icon: Image {
        switch self {
        case .document: Image(systemName: "doc.text")
        case .contents: Image(systemName: "list.bullet")
        }
    }

    public var title: LocalizedStringKey {
        switch self {
        case .document: L.Common.document
        case .contents: L.Common.model
        }
    }
}
