import AppDomain
import Domain
import SwiftRexArchitecture
import SwiftUI
import Vitral
import VitralTokens

// MARK: - EditorView (container)

@BoundTo(EditorFeature.self)
public struct EditorView: View {
    public var body: some View {
        // All bidirectional field bindings are created here, once, in the container.
        // Each binding's `get` re-reads from the viewModel so it always returns the latest value.

        let inspectorTabBinding = Binding(
            get: { viewStore.state.inspectorTab.value },
            set: { viewStore.dispatch(.setInspectorTab($0)) }
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
                fraction: Binding(
                    get: { viewStore.state.compartments.value.first { $0.id == id }?.fraction ?? 0 },
                    set: { viewStore.dispatch(.updateCompartmentFraction(id: id, fraction: $0)) }
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
                rate: Binding(
                    get: { viewStore.state.links.value.first { $0.id == idx }?.rate ?? 0 },
                    set: { viewStore.dispatch(.updateLinkRate(index: idx, rate: $0)) }
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
                canDelete: n.canDelete,
                compartmentCount: n.compartmentCount
            )
        }

        return EditorContent(
            documentName:        documentNameBinding,
            documentDescription: documentDescriptionBinding,
            field:               fieldBinding,
            lingo:               viewStore.state.lingo.value,
            halfLife:           viewStore.state.halfLife,
            nuclides:           viewStore.state.nuclides.value,
            compartments:       viewStore.state.compartments.value,
            links:              viewStore.state.links.value,
            selectedCompartmentId: viewStore.state.selectedCompartmentId,
            selectedLinkIndex:  viewStore.state.selectedLinkIndex,
            inspectorTab:       inspectorTabBinding,
            compartmentBindings: compBindings,
            linkBindings:        linkBindings,
            nuclideBindings:     nuclideBindings,
            isLeftPanelVisible:  viewStore.state.isLeftPanelVisible,
            isRightPanelVisible: viewStore.state.isRightPanelVisible,
            showKValues:         viewStore.state.showKValues,
            linkingBannerText:   viewStore.state.linkingBannerText,
            selectionFooterLabel: viewStore.state.selectionFooterLabel,
            validationIssues:    viewStore.state.validationIssues.value,
            canvasOffsetX:      viewStore.state.canvasOffsetX,
            canvasOffsetY:      viewStore.state.canvasOffsetY,
            canvasScale:        viewStore.state.canvasScale,
            pinchScale:              viewStore.state.pinchScale,
            pinchOffset:              viewStore.state.pinchOffset.value,
            compartmentDragOriginId: viewStore.state.compartmentDragOriginId,
            compartmentDragOriginX:  viewStore.state.compartmentDragOriginX,
            compartmentDragOriginY:  viewStore.state.compartmentDragOriginY,
            variants:                viewStore.state.variants.value,
            editingVariant:          viewStore.state.editingVariant,
            renamingVariant:         viewStore.state.renamingVariant,
            variantRenameDraft:      viewStore.binding(.state(\.variantRenameDraft).action(\.setVariantRenameDraft)),
            onSelectCompartment: { viewStore.dispatch(.selectCompartment($0)) },
            onSelectLink:        { viewStore.dispatch(.selectLink($0)) },
            onToggleLeftPanel:   { viewStore.dispatch(.toggleLeftPanel) },
            onToggleRightPanel:  { viewStore.dispatch(.toggleRightPanel) },
            onToggleKValues:     { viewStore.dispatch(.toggleKValues) },
            onBeginLinking:      { viewStore.dispatch(.beginLinking) },
            onLinkStep:          { viewStore.dispatch(.linkStep($0)) },
            onCancelLinking:     { viewStore.dispatch(.cancelLinking) },
            onAddCompartment:    { viewStore.dispatch(.addCompartment($0)) },
            onDeleteCompartment: { viewStore.dispatch(.deleteCompartment(id: $0)) },
            onDeleteLink:        { viewStore.dispatch(.deleteLink(index: $0)) },
            onMoveCompartment:       { viewStore.dispatch(.moveCompartment(id: $0, x: $1, y: $2)) },
            onBeginCompartmentDrag:  { viewStore.dispatch(.beginCompartmentDrag(id: $0, x: $1, y: $2)) },
            onEndCompartmentDrag:    { viewStore.dispatch(.endCompartmentDrag) },
            onCanvasTouches:         { viewStore.dispatch(.canvasTouchesChanged($0)) },
            onEndCanvasTouches:      { viewStore.dispatch(.canvasTouchesEnded) },
            onSetCanvasTransform:    { viewStore.dispatch(.setCanvasTransform(offsetX: $0, offsetY: $1, scale: $2)) },
            inspectorSheet:          viewStore.binding(.state(\.isInspectorSheetOpen).action(\.setInspectorSheet)),
            modelListSheet:          viewStore.binding(.state(\.isModelListSheetOpen).action(\.setModelListSheet)),
            onAddNuclide:            { viewStore.dispatch(.addNuclide) },
            onDeleteNuclide:         { viewStore.dispatch(.deleteNuclide(id: $0)) },
            onAddVariant:            { viewStore.dispatch(.addVariant(name: $0)) },
            onDeleteVariant:         { viewStore.dispatch(.deleteVariant(name: $0)) },
            onSelectEditingVariant:  { viewStore.dispatch(.selectEditingVariant($0)) },
            onBeginVariantRename:    { viewStore.dispatch(.beginVariantRename($0)) },
            onCommitVariantRename:   { viewStore.dispatch(.commitVariantRename) },
            onCancelVariantRename:   { viewStore.dispatch(.cancelVariantRename) }
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
    let nuclides: [EditorFeature.NuclideRow]
    let compartments: [EditorFeature.CompartmentRow]
    let links: [EditorFeature.LinkRow]
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
    var onCanvasTouches: (EditorFeature.CanvasTouches) -> Void
    var onEndCanvasTouches: () -> Void
    var onSetCanvasTransform: (Double, Double, Double) -> Void
    var inspectorSheet: Binding<Bool>
    var modelListSheet: Binding<Bool>
    var onAddNuclide: () -> Void
    var onDeleteNuclide: (String) -> Void
    var onAddVariant: (String) -> Void
    var onDeleteVariant: (String) -> Void
    var onSelectEditingVariant: (String?) -> Void
    var onBeginVariantRename: (String) -> Void
    var onCommitVariantRename: () -> Void
    var onCancelVariantRename: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    /// The phone layout whenever either dimension is compact: a landscape iPhone has regular width
    /// but not the height for three columns. A real iPad (or an unfolded foldable) is regular both
    /// ways and gets the panels.
    private var isCompact: Bool { hSize == .compact || vSize == .compact }

    var body: some View {
        ZStack {
            Backdrop()
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
                Hairline(.vertical)
            }

            ZStack(alignment: .top) {
                canvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .vertical)

                if let text = linkingBannerText {
                    Banner(Text(text), style: .custom(foreground: .accent, background: .infoSurface, icon: Image(systemName: "arrow.triangle.branch")))
                    .trailing { Button("Cancel", action: onCancelLinking).font(.bodyStrong) }
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Labels where they fit, icons where they don't: never a wrapped "Co m…".
                VStack {
                    Spacer()
                    ViewThatFits(in: .horizontal) {
                        canvasToolbar.labelStyle(.titleAndIcon)
                        canvasToolbar.labelStyle(.iconOnly)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
                }
            }

            if isRightPanelVisible {
                Hairline(.vertical)
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
                    variantRenameDraft: variantRenameDraft
                )
                .frame(width: 326)
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
            // Edge to edge: the navigation bar and the bottom buttons are glass over the canvas,
            // not bars over a flat background.
            canvas
                .ignoresSafeArea()
            // A soft fade where the canvas runs under the navigation bar and the buttons.
            EdgeFade(.top)
            EdgeFade(.bottom)

            if let text = linkingBannerText {
                Banner(Text(text), style: .custom(foreground: .accent, background: .infoSurface, icon: Image(systemName: "arrow.triangle.branch")))
                    .trailing { Button("Cancel", action: onCancelLinking).font(.bodyStrong) }
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(), value: text)
            }

        }
        // In the safe area, not on top of it: the system knows the buttons are there, so the fade
        // and anything else that respects the safe area clears them on any device.
        .safeAreaInset(edge: .bottom) { compactBottomToolbar }
        .sheet(isPresented: inspectorSheet) { inspectorSheetContent }
        .sheet(isPresented: modelListSheet) { modelListSheetContent }
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
            pinchScale: pinchScale,
            pinchOffset: pinchOffset,
            compartmentDragOriginId: compartmentDragOriginId,
            compartmentDragOriginX: compartmentDragOriginX,
            compartmentDragOriginY: compartmentDragOriginY,
            onSelectCompartment: { id in
                if linkingBannerText != nil { if let id { onLinkStep(id) } }
                else {
                    onSelectCompartment(id)
                    if isCompact, id != nil { inspectorSheet.wrappedValue = true }
                }
            },
            onSelectLink: { idx in
                onSelectLink(idx)
                if isCompact, idx != nil { inspectorSheet.wrappedValue = true }
            },
            onMoveCompartment: onMoveCompartment,
            onBeginCompartmentDrag: onBeginCompartmentDrag,
            onEndCompartmentDrag: onEndCompartmentDrag,
            onCanvasTouches: onCanvasTouches,
            onEndCanvasTouches: onEndCanvasTouches,
            onSetCanvasTransform: onSetCanvasTransform
        )
    }

    // MARK: - Compact bottom toolbar

    private var compactBottomToolbar: some View {
        GlassEffectContainer(spacing: 9) {
        HStack(spacing: 9) {
            Pill {
                Button { onAddCompartment(.steel) } label: {
                    Label("Compartment", systemImage: "plus.square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16).frame(height: 46)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Pill(isActive: linkingBannerText != nil) {
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
            Pill {
                Button { modelListSheet.wrappedValue = true } label: {
                    Label("Model", systemImage: "list.bullet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16).frame(height: 46)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        }
        .padding(.horizontal, 14).padding(.bottom, 8)
    }

    // MARK: - Inspector sheet (iPhone)

    private var inspectorSheetContent: some View {
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
                        inspectorSheet.wrappedValue = false
                        if let id = selectedCompartmentId { onDeleteCompartment(id) }
                        else if let idx = selectedLinkIndex { onDeleteLink(idx) }
                    },
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
                    variantRenameDraft: variantRenameDraft
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle(title)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { inspectorSheet.wrappedValue = false }
                }
            }
        }
        .presentationDetents([.fraction(0.80)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Model list sheet (iPhone)

    private var modelListSheetContent: some View {
        NavigationStack {
            EditorModelListPanel(
                lingo: lingo, nuclides: nuclides, compartments: compartments, links: links,
                selectedCompartmentId: selectedCompartmentId,
                selectedLinkIndex: selectedLinkIndex,
                selectionFooterLabel: selectionFooterLabel,
                onSelectCompartment: { id in modelListSheet.wrappedValue = false; onSelectCompartment(id) },
                onSelectLink: { idx in modelListSheet.wrappedValue = false; onSelectLink(idx) },
                onDeleteSelected: {
                    modelListSheet.wrappedValue = false
                    if let id = selectedCompartmentId { onDeleteCompartment(id) }
                    else if let idx = selectedLinkIndex { onDeleteLink(idx) }
                }
            )
            .navigationTitle("Model")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { modelListSheet.wrappedValue = false }
                }
            }
        }
        .presentationDetents([.fraction(0.80)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Canvas toolbar (iPad center bottom)

    private var canvasToolbar: some View {
        HStack(spacing: 8) {
            Pill {
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
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 15).frame(height: 44)
                }
            }
            Pill(isActive: linkingBannerText != nil) {
                Button {
                    if linkingBannerText != nil { onCancelLinking() } else { onBeginLinking() }
                } label: {
                    Label("Link", systemImage: "arrow.triangle.branch")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(linkingBannerText != nil ? Color.accentColor : .primary)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 15).frame(height: 44)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Pill(isActive: showKValues) {
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
                    inspectorSheet.wrappedValue = true
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
