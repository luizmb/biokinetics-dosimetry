import AppDomain
import Domain
import SwiftRexArchitecture
import SwiftUI
import UIComponents

// MARK: - EditorView (container)

@BoundTo(EditorFeature.self)
public struct EditorView: View {
    public var body: some View {
        // All bidirectional field bindings are created here, once, in the container.
        // Each binding's `get` re-reads from the viewModel so it always returns the latest value.

        let inspectorTabBinding = Binding(
            get: { viewModel.inspectorTab },
            set: { viewModel.dispatch(.setInspectorTab($0)) }
        )

        // Compartment field bindings — nil when no compartment is selected.
        let compBindings: CompartmentFieldBindings? = viewModel.selectedCompartmentId.flatMap { id in
            guard viewModel.compartments.contains(where: { $0.id == id }) else { return nil }
            let isMultiNuclide = viewModel.nuclides.count > 1
            return CompartmentFieldBindings(  // isMultiNuclide used to guard dispatch below
                name: Binding(
                    get: { viewModel.compartments.first { $0.id == id }?.name ?? "" },
                    set: { viewModel.dispatch(.updateCompartmentName(id: id, name: $0)) }
                ),
                follow: Binding(
                    get: { viewModel.compartments.first { $0.id == id }?.follow ?? false },
                    set: { viewModel.dispatch(.updateCompartmentFollow(id: id, value: $0)) }
                ),
                dispose: Binding(
                    get: { viewModel.compartments.first { $0.id == id }?.dispose ?? false },
                    set: { viewModel.dispatch(.updateCompartmentDispose(id: id, value: $0)) }
                ),
                intake: Binding(
                    get: { viewModel.compartments.first { $0.id == id }?.intake ?? false },
                    set: { viewModel.dispatch(.updateCompartmentIntake(id: id, value: $0)) }
                ),
                nuclideId: Binding(
                    get: { viewModel.compartments.first { $0.id == id }?.nuclideId ?? "" },
                    set: { if isMultiNuclide { viewModel.dispatch(.setCompartmentNuclide(compartmentId: id, nuclideId: $0)) } }
                )
            )
        }

        // Link field bindings — nil when no link is selected.
        let linkBindings: LinkFieldBindings? = viewModel.selectedLinkIndex.flatMap { idx in
            guard viewModel.links.contains(where: { $0.id == idx }) else { return nil }
            return LinkFieldBindings(
                rate: Binding(
                    get: { viewModel.links.first { $0.id == idx }?.rate ?? 0 },
                    set: { viewModel.dispatch(.updateLinkRate(index: idx, rate: $0)) }
                )
            )
        }

        let documentNameBinding = Binding(
            get: { viewModel.documentName },
            set: { viewModel.dispatch(.renameDocument($0)) }
        )

        let documentDescriptionBinding = Binding(
            get: { viewModel.documentDescription },
            set: { viewModel.dispatch(.updateDescription($0)) }
        )

        let fieldBinding = Binding(
            get: { viewModel.field },
            set: { viewModel.dispatch(.updateField($0)) }
        )

        // Nuclide field bindings — one entry per nuclide in the document.
        let nuclideBindings: [NuclideEditBinding] = viewModel.nuclides.map { n in
            NuclideEditBinding(
                id: n.id,
                name: Binding(
                    get: { viewModel.nuclides.first { $0.id == n.id }?.name ?? "" },
                    set: { viewModel.dispatch(.updateNuclideName(id: n.id, name: $0)) }
                ),
                halfLife: Binding(
                    get: { viewModel.nuclides.first { $0.id == n.id }?.halfLife ?? 0 },
                    set: { viewModel.dispatch(.updateNuclideHalfLife(id: n.id, halfLife: $0)) }
                ),
                canDelete: n.canDelete,
                compartmentCount: n.compartmentCount
            )
        }

        return EditorContent(
            documentName:        documentNameBinding,
            documentDescription: documentDescriptionBinding,
            field:               fieldBinding,
            lingo:               viewModel.lingo,
            halfLife:           viewModel.halfLife,
            nuclides:           viewModel.nuclides,
            compartments:       viewModel.compartments,
            links:              viewModel.links,
            selectedCompartmentId: viewModel.selectedCompartmentId,
            selectedLinkIndex:  viewModel.selectedLinkIndex,
            inspectorTab:       inspectorTabBinding,
            compartmentBindings: compBindings,
            linkBindings:        linkBindings,
            nuclideBindings:     nuclideBindings,
            isLeftPanelVisible:  viewModel.isLeftPanelVisible,
            isRightPanelVisible: viewModel.isRightPanelVisible,
            showKValues:         viewModel.showKValues,
            linkingBannerText:   viewModel.linkingBannerText,
            selectionFooterLabel: viewModel.selectionFooterLabel,
            validationIssues:    viewModel.validationIssues,
            canvasOffsetX:      viewModel.canvasOffsetX,
            canvasOffsetY:      viewModel.canvasOffsetY,
            canvasScale:        viewModel.canvasScale,
            compartmentDragOriginId: viewModel.compartmentDragOriginId,
            compartmentDragOriginX:  viewModel.compartmentDragOriginX,
            compartmentDragOriginY:  viewModel.compartmentDragOriginY,
            canvasPanOriginX:        viewModel.canvasPanOriginX,
            canvasPanOriginY:        viewModel.canvasPanOriginY,
            canvasPinchOriginScale:  viewModel.canvasPinchOriginScale,
            isInspectorSheetOpen:    viewModel.isInspectorSheetOpen,
            isModelListSheetOpen:    viewModel.isModelListSheetOpen,
            onSelectCompartment: { viewModel.dispatch(.selectCompartment($0)) },
            onSelectLink:        { viewModel.dispatch(.selectLink($0)) },
            onToggleLeftPanel:   { viewModel.dispatch(.toggleLeftPanel) },
            onToggleRightPanel:  { viewModel.dispatch(.toggleRightPanel) },
            onToggleKValues:     { viewModel.dispatch(.toggleKValues) },
            onBeginLinking:      { viewModel.dispatch(.beginLinking) },
            onLinkStep:          { viewModel.dispatch(.linkStep($0)) },
            onCancelLinking:     { viewModel.dispatch(.cancelLinking) },
            onAddCompartment:    { viewModel.dispatch(.addCompartment($0)) },
            onDeleteCompartment: { viewModel.dispatch(.deleteCompartment(id: $0)) },
            onDeleteLink:        { viewModel.dispatch(.deleteLink(index: $0)) },
            onMoveCompartment:       { viewModel.dispatch(.moveCompartment(id: $0, x: $1, y: $2)) },
            onBeginCompartmentDrag:  { viewModel.dispatch(.beginCompartmentDrag(id: $0, x: $1, y: $2)) },
            onEndCompartmentDrag:    { viewModel.dispatch(.endCompartmentDrag) },
            onBeginCanvasPan:        { viewModel.dispatch(.beginCanvasPan(originX: $0, originY: $1)) },
            onEndCanvasPan:          { viewModel.dispatch(.endCanvasPan) },
            onBeginCanvasPinch:      { viewModel.dispatch(.beginCanvasPinch(originScale: $0)) },
            onEndCanvasPinch:        { viewModel.dispatch(.endCanvasPinch) },
            onSetCanvasTransform:    { viewModel.dispatch(.setCanvasTransform(offsetX: $0, offsetY: $1, scale: $2)) },
            onSetInspectorSheet:     { viewModel.dispatch(.setInspectorSheet($0)) },
            onSetModelListSheet:     { viewModel.dispatch(.setModelListSheet($0)) },
            onAddNuclide:            { viewModel.dispatch(.addNuclide) },
            onDeleteNuclide:         { viewModel.dispatch(.deleteNuclide(id: $0)) }
        )
        .inlineNavigationTitle()
    }
}

// MARK: - EditorContent (pure view)

struct EditorContent: View {
    // MARK: Read-only view state
    var documentName:        Binding<String>
    var documentDescription: Binding<String>
    var field:               Binding<ModelField>
    let lingo: FieldLingo
    let halfLife: Double
    let nuclides: [EditorFeature.ViewModel.NuclideRow]
    let compartments: [EditorFeature.ViewModel.CompartmentRow]
    let links: [EditorFeature.ViewModel.LinkRow]
    let selectedCompartmentId: String?
    let selectedLinkIndex: Int?

    // MARK: Bidirectional bindings (created by the container)
    var inspectorTab: Binding<EditorFeature.InspectorTab>
    var compartmentBindings: CompartmentFieldBindings?
    var linkBindings: LinkFieldBindings?
    var nuclideBindings: [NuclideEditBinding]

    // MARK: Read-only display state
    let isLeftPanelVisible: Bool
    let isRightPanelVisible: Bool
    let showKValues: Bool
    let linkingBannerText: String?
    let selectionFooterLabel: String?
    let validationIssues: [CompartmentalModel.ValidationIssue]
    let canvasOffsetX: Double
    let canvasOffsetY: Double
    let canvasScale: Double
    let compartmentDragOriginId: String?
    let compartmentDragOriginX: Double
    let compartmentDragOriginY: Double
    let canvasPanOriginX: Double?
    let canvasPanOriginY: Double?
    let canvasPinchOriginScale: Double?
    let isInspectorSheetOpen: Bool
    let isModelListSheetOpen: Bool

    // MARK: One-way action callbacks
    var onSelectCompartment: (String?) -> Void
    var onSelectLink: (Int?) -> Void
    var onToggleLeftPanel: () -> Void
    var onToggleRightPanel: () -> Void
    var onToggleKValues: () -> Void
    var onBeginLinking: () -> Void
    var onLinkStep: (String) -> Void
    var onCancelLinking: () -> Void
    var onAddCompartment: (CompartmentTint) -> Void
    var onDeleteCompartment: (String) -> Void
    var onDeleteLink: (Int) -> Void
    var onMoveCompartment: (String, Double, Double) -> Void
    var onBeginCompartmentDrag: (String, Double, Double) -> Void
    var onEndCompartmentDrag: () -> Void
    var onBeginCanvasPan: (Double, Double) -> Void
    var onEndCanvasPan: () -> Void
    var onBeginCanvasPinch: (Double) -> Void
    var onEndCanvasPinch: () -> Void
    var onSetCanvasTransform: (Double, Double, Double) -> Void
    var onSetInspectorSheet: (Bool) -> Void
    var onSetModelListSheet: (Bool) -> Void
    var onAddNuclide: () -> Void
    var onDeleteNuclide: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSize
    private var isCompact: Bool { hSize == .compact }

    var body: some View {
        ZStack {
            GlassAppBackground()
            if isCompact { compactLayout } else { regularLayout }
        }
        .navigationTitle(documentName.wrappedValue)
        .toolbar { toolbarItems }
    }

    // MARK: - Regular (iPad 3-column)

    private var regularLayout: some View {
        HStack(spacing: 0) {
            if isLeftPanelVisible {
                EditorModelListPanel(
                    lingo: lingo, nuclides: nuclides, compartments: compartments, links: links,
                    selectedCompartmentId: selectedCompartmentId,
                    selectedLinkIndex: selectedLinkIndex,
                    selectionFooterLabel: selectionFooterLabel,
                    onSelectCompartment: onSelectCompartment,
                    onSelectLink: onSelectLink,
                    onDeleteSelected: {
                        if let id = selectedCompartmentId { onDeleteCompartment(id) }
                        else if let idx = selectedLinkIndex { onDeleteLink(idx) }
                    }
                )
                .frame(width: 264)
                .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                GlassPanelRevealStrip(edge: .leading, action: onToggleLeftPanel)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            GlassVDivider()

            ZStack(alignment: .top) {
                canvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let text = linkingBannerText {
                    GlassLinkingBanner(message: text, onCancel: onCancelLinking)
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                VStack { Spacer(); canvasToolbar.padding(.bottom, 16) }
            }

            GlassVDivider()

            if isRightPanelVisible {
                EditorInspectorPanel(
                    documentName: documentName,
                    documentDescription: documentDescription,
                    field: field,
                    lingo: lingo,
                    nuclides: nuclides,
                    compartments: compartments,
                    links: links,
                    selectedCompartmentId: selectedCompartmentId,
                    selectedLinkIndex: selectedLinkIndex,
                    inspectorTab: inspectorTab,
                    compartmentBindings: compartmentBindings,
                    linkBindings: linkBindings,
                    nuclideBindings: nuclideBindings,
                    validationIssues: validationIssues,
                    onSelectCompartment: onSelectCompartment,
                    onSelectLink: onSelectLink,
                    onBeginLinking: onBeginLinking,
                    onDeleteSelected: {
                        if let id = selectedCompartmentId { onDeleteCompartment(id) }
                        else if let idx = selectedLinkIndex { onDeleteLink(idx) }
                    },
                    onAddNuclide: onAddNuclide,
                    onDeleteNuclide: onDeleteNuclide
                )
                .frame(width: 326)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                GlassPanelRevealStrip(edge: .trailing, action: onToggleRightPanel)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isLeftPanelVisible)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isRightPanelVisible)
        .animation(.spring(), value: linkingBannerText != nil)
    }

    // MARK: - Compact (iPhone)

    private var compactLayout: some View {
        ZStack(alignment: .top) {
            canvas
                .padding(.bottom, 90)

            if let text = linkingBannerText {
                GlassLinkingBanner(message: text, onCancel: onCancelLinking)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(), value: text)
            }

            VStack { Spacer(); compactBottomToolbar }
        }
        .sheet(isPresented: Binding(
            get: { isInspectorSheetOpen },
            set: { onSetInspectorSheet($0) }
        )) { inspectorSheet }
        .sheet(isPresented: Binding(
            get: { isModelListSheetOpen },
            set: { onSetModelListSheet($0) }
        )) { modelListSheet }
    }

    // MARK: - Canvas (shared)

    private var canvas: some View {
        CompartmentCanvasView(
            compartments: compartments, links: links,
            selectedCompartmentId: selectedCompartmentId,
            selectedLinkIndex: selectedLinkIndex,
            showKValues: showKValues,
            isLinking: linkingBannerText != nil,
            canvasOffsetX: canvasOffsetX, canvasOffsetY: canvasOffsetY,
            canvasScale: canvasScale,
            compartmentDragOriginId: compartmentDragOriginId,
            compartmentDragOriginX: compartmentDragOriginX,
            compartmentDragOriginY: compartmentDragOriginY,
            canvasPanOriginX: canvasPanOriginX,
            canvasPanOriginY: canvasPanOriginY,
            canvasPinchOriginScale: canvasPinchOriginScale,
            onSelectCompartment: { id in
                if linkingBannerText != nil { if let id { onLinkStep(id) } }
                else {
                    onSelectCompartment(id)
                    if isCompact, id != nil { onSetInspectorSheet(true) }
                }
            },
            onSelectLink: { idx in
                onSelectLink(idx)
                if isCompact, idx != nil { onSetInspectorSheet(true) }
            },
            onMoveCompartment: onMoveCompartment,
            onBeginCompartmentDrag: onBeginCompartmentDrag,
            onEndCompartmentDrag: onEndCompartmentDrag,
            onBeginCanvasPan: onBeginCanvasPan,
            onEndCanvasPan: onEndCanvasPan,
            onBeginCanvasPinch: onBeginCanvasPinch,
            onEndCanvasPinch: onEndCanvasPinch,
            onSetCanvasTransform: onSetCanvasTransform
        )
    }

    // MARK: - Compact bottom toolbar

    private var compactBottomToolbar: some View {
        HStack(spacing: 9) {
            GPill(intensity: 0.8) {
                Button { onAddCompartment(.steel) } label: {
                    Label("Compartment", systemImage: "plus.square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16).frame(height: 46)
                }
                .buttonStyle(PlainButtonStyle())
            }
            GPill(intensity: linkingBannerText != nil ? 1.0 : 0.8) {
                Button {
                    if linkingBannerText != nil { onCancelLinking() } else { onBeginLinking() }
                } label: {
                    Label("Link", systemImage: "arrow.triangle.branch")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(linkingBannerText != nil ? Color.accentColor : .primary)
                        .padding(.horizontal, 16).frame(height: 46)
                }
                .buttonStyle(PlainButtonStyle())
            }
            GPill(intensity: 0.8) {
                Button { onSetModelListSheet(true) } label: {
                    Label("Model", systemImage: "list.bullet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16).frame(height: 46)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 14).padding(.bottom, 30)
    }

    // MARK: - Inspector sheet (iPhone)

    private var inspectorSheet: some View {
        let title: String = {
            if let id = selectedCompartmentId {
                return compartments.first(where: { $0.id == id })?.name ?? "Inspector"
            } else if let idx = selectedLinkIndex {
                return "K\(idx + 1)"
            }
            return "Document"
        }()
        return NavigationStack {
            ScrollView {
                EditorInspectorPanel(
                    documentName: documentName,
                    documentDescription: documentDescription,
                    field: field,
                    lingo: lingo,
                    nuclides: nuclides,
                    compartments: compartments,
                    links: links,
                    selectedCompartmentId: selectedCompartmentId,
                    selectedLinkIndex: selectedLinkIndex,
                    inspectorTab: inspectorTab,
                    compartmentBindings: compartmentBindings,
                    linkBindings: linkBindings,
                    nuclideBindings: nuclideBindings,
                    validationIssues: validationIssues,
                    onSelectCompartment: onSelectCompartment,
                    onSelectLink: onSelectLink,
                    onBeginLinking: onBeginLinking,
                    onDeleteSelected: {
                        onSetInspectorSheet(false)
                        if let id = selectedCompartmentId { onDeleteCompartment(id) }
                        else if let idx = selectedLinkIndex { onDeleteLink(idx) }
                    },
                    onAddNuclide: onAddNuclide,
                    onDeleteNuclide: onDeleteNuclide
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle(title)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSetInspectorSheet(false) }
                }
            }
        }
        .presentationDetents([.fraction(0.80)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Model list sheet (iPhone)

    private var modelListSheet: some View {
        NavigationStack {
            EditorModelListPanel(
                lingo: lingo, nuclides: nuclides, compartments: compartments, links: links,
                selectedCompartmentId: selectedCompartmentId,
                selectedLinkIndex: selectedLinkIndex,
                selectionFooterLabel: selectionFooterLabel,
                onSelectCompartment: { id in onSetModelListSheet(false); onSelectCompartment(id) },
                onSelectLink: { idx in onSetModelListSheet(false); onSelectLink(idx) },
                onDeleteSelected: {
                    onSetModelListSheet(false)
                    if let id = selectedCompartmentId { onDeleteCompartment(id) }
                    else if let idx = selectedLinkIndex { onDeleteLink(idx) }
                }
            )
            .navigationTitle("Model")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSetModelListSheet(false) }
                }
            }
        }
        .presentationDetents([.fraction(0.80)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Canvas toolbar (iPad center bottom)

    private var canvasToolbar: some View {
        HStack(spacing: 8) {
            GPill(intensity: 0.85) {
                Menu {
                    ForEach(CompartmentTint.allCases, id: \.self) { tint in
                        Button { onAddCompartment(tint) } label: {
                            Label(tint.rawValue.capitalized, systemImage: "square.fill")
                        }
                    }
                } label: {
                    Label("Compartment", systemImage: "plus.square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 15).frame(height: 44)
                }
            }
            GPill(intensity: linkingBannerText != nil ? 1.0 : 0.85) {
                Button {
                    if linkingBannerText != nil { onCancelLinking() } else { onBeginLinking() }
                } label: {
                    Label("Link", systemImage: "arrow.triangle.branch")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(linkingBannerText != nil ? Color.accentColor : .primary)
                        .padding(.horizontal, 15).frame(height: 44)
                }
                .buttonStyle(PlainButtonStyle())
            }
            GPill(intensity: showKValues ? 1.0 : 0.85) {
                Button(action: onToggleKValues) {
                    Text("K")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(showKValues ? Color.accentColor : .primary)
                        .padding(.horizontal, 15).frame(height: 44)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Toolbar items

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .platformNavigationLeading) {
            if !validationIssues.isEmpty {
                let errorCount = validationIssues.filter { $0.severity == .error }.count
                let tint: Color = errorCount > 0 ? .orange : .yellow
                Label("\(validationIssues.count)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(tint.opacity(0.12), in: Capsule())
            }
        }
        ToolbarItemGroup(placement: .platformNavigationTrailing) {
            if !isCompact {
                Button(action: onToggleKValues) {
                    Image(systemName: showKValues ? "eye" : "eye.slash")
                }
                .tint(showKValues ? .accentColor : .secondary)
                panelToggle(side: .leading,  isVisible: isLeftPanelVisible,  action: onToggleLeftPanel)
                panelToggle(side: .trailing, isVisible: isRightPanelVisible, action: onToggleRightPanel)
            } else {
                Button(action: onToggleKValues) {
                    Image(systemName: showKValues ? "eye" : "eye.slash")
                }
                .tint(showKValues ? .accentColor : .secondary)

                // Document inspector button: clears selection and opens the inspector
                // in Document mode (shows nuclides + half-life).
                Button {
                    onSelectCompartment(nil)   // also clears selectedLinkIndex via reducer
                    onSetInspectorSheet(true)
                } label: {
                    Image(systemName: "doc.text")
                }
            }
        }
    }

    private func panelToggle(side: HorizontalEdge, isVisible: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: side == .leading ? "sidebar.left" : "sidebar.right")
                .symbolVariant(isVisible ? .fill : .none)
        }
        .tint(isVisible ? .accentColor : .secondary)
    }
}
