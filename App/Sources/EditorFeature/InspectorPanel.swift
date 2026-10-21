import AppDomain
import Domain
import SwiftUI
import Localization
import Vitral

// MARK: - Field binding groups
// Created in the @BoundTo container; the pure inspector views just consume them.

struct CompartmentFieldBindings {
    var name:      Binding<String>
    var tint:      Binding<CompartmentTint>
    var follow:    Binding<Bool>
    var dispose:   Binding<Bool>
    var intake:    Binding<Bool>
    /// The fraction's field: what it shows, and the text typed into it.
    var fractionText: Binding<String>
    var nuclideId: Binding<String>
}

struct LinkFieldBindings {
    /// The rate's field: what it shows, and the text typed into it.
    var rateText: Binding<String>
}

struct NuclideEditBinding {
    var id:             String
    var name:           Binding<String>
    var halfLife:       Binding<Double>
    /// The half-life's field: what it shows, and the text typed into it.
    var halfLifeText:   Binding<String>
    var canDelete:      Bool
    var compartmentCount: Int
}

// MARK: - EditorInspectorPanel (pure)

/// The right panel: what is being edited. A compartment or a transfer (its details and its
/// relationships, side by side), a transfer being made, or, with nothing asked for, a word saying so.
struct EditorInspectorPanel: View {
    let lingo: FieldLingo
    let units: WorkingUnits
    let nuclides:             [EditorFeature.NuclideRow]
    let compartments:         [EditorFeature.CompartmentRow]
    let links:                [EditorFeature.LinkRow]
    let selectedCompartmentId: String?
    let selectedLinkIndex:    Int?
    let transferDraft:        EditorFeature.TransferDraft?

    // Bidirectional bindings (created by the container, nil when nothing is selected)
    @Binding var inspectorTab:    EditorFeature.InspectorTab
    var compartmentBindings:      CompartmentFieldBindings?
    var linkBindings:             LinkFieldBindings?

    // One-way action callbacks (no return value needed)
    var onEditCompartment:   (String) -> Void
    var onEditLink:          (Int) -> Void
    var onBeginTransfer:     (String?, String?) -> Void
    var onSetTransferFrom:   (String?) -> Void
    var onSetTransferTo:     (String?) -> Void
    var onCreateTransfer:    () -> Void
    var onCancelTransfer:    () -> Void
    var onDeleteSelected:    () -> Void

    /// The screen's appearance, from its parent's view state.
    let colorScheme: ColorScheme
    /// A number field was left: what it shows is the value again.
    var onEndNumberEditing: () -> Void
    private var dark: Bool { colorScheme == .dark }

    private var selectedComp: EditorFeature.CompartmentRow? {
        compartments.first { $0.id == selectedCompartmentId }
    }
    private var selectedLink: EditorFeature.LinkRow? {
        selectedLinkIndex.flatMap { idx in links.first { $0.id == idx } }
    }

    var body: some View {
        if let draft = transferDraft {
            headed { page { transferForm(draft) } }
        } else if let comp = selectedComp, let cb = compartmentBindings {
            // Details and relationships side by side: tap a segment or swipe between them.
            SegmentedPages(selection: $inspectorTab, showsTitles: true) { tab in
                page { compartmentInspector(comp, bindings: cb, tab: tab) }
            }
        } else if let link = selectedLink, let lb = linkBindings {
            SegmentedPages(selection: $inspectorTab, showsTitles: true) { tab in
                page { linkInspector(link, bindings: lb, tab: tab) }
            }
        } else {
            headed {
                EmptyState(L.Editor.nothingSelected, message: Text(L.Editor.pickSomethingToEdit), icon: Image(systemName: "hand.tap"))
            }
        }
    }

    /// Under the panel's own heading, for what has no segments of its own.
    private func headed<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(L.Editor.inspectorHeading)
                    .font(TypeToken.sectionLabel)
                    .kerning(0.5)
                    .foregroundStyle(Color(.inkFaint, scheme: colorScheme))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)
            Hairline()
            content()
        }
    }

    // MARK: - New transfer

    /// Its two ends, chosen from the model's compartments; made once both are chosen and differ.
    @ViewBuilder
    private func transferForm(_ draft: EditorFeature.TransferDraft) -> some View {
        inspectorHead(branch: true, title: Text(L.Editor.newTransfer), sub: Text(L.Common.transfers))

        let ends = [ChoiceOption<String?>(nil, title: L.Common.none)]
            + compartments.map { ChoiceOption<String?>($0.id, title: Text(verbatim: $0.name)) }
        Panel(cornerRadius: 16, padding: 0) {
            VStack(spacing: 0) {
                FieldPicker(L.Editor.from, selection: Binding(get: { draft.from }, set: onSetTransferFrom), options: ends)
                    .padding(.horizontal, 15)
                Hairline()
                FieldPicker(L.Editor.to, selection: Binding(get: { draft.to }, set: onSetTransferTo), options: ends)
                    .padding(.horizontal, 15)
            }
        }
        .padding(.bottom, 18)

        HStack {
            Button(L.Common.cancel, action: onCancelTransfer)
                .buttonStyle(PlainButtonStyle())
                .foregroundStyle(.inkMuted)
            Spacer()
            Button(action: onCreateTransfer) {
                Label(L.Editor.addTransfer, systemImage: "plus.circle")
                    .font(TypeToken.bodyStrong)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundStyle(draft.isComplete ? Color(.accent, scheme: colorScheme) : Color(.inkFaint, scheme: colorScheme))
            .disabled(!draft.isComplete)
        }
    }

    /// One page of the inspector: its content, scrolling under the segments.
    private func page<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content() }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
        }
    }

    // MARK: - Compartment inspector

    @ViewBuilder
    private func compartmentInspector(
        _ comp: EditorFeature.CompartmentRow,
        bindings: CompartmentFieldBindings,
        tab: EditorFeature.InspectorTab
    ) -> some View {
        inspectorHead(swatch: comp.tint, title: Text(verbatim: comp.name), sub: Text(L.Common.compartment))

        switch tab {
        case .details:       compartmentDetails(comp, bindings: bindings)
        case .relationships: compartmentRelationships(comp)
        }
    }

    @ViewBuilder
    private func compartmentDetails(
        _ comp: EditorFeature.CompartmentRow,
        bindings: CompartmentFieldBindings
    ) -> some View {
        SectionLabel(L.Common.name)
        FieldText(L.Common.name, text: bindings.name)
        .padding(.bottom, 18)

        SectionLabel(L.Editor.color)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
            ForEach(Array(CompartmentTint.allCases.enumerated()), id: \.element) { index, tint in
                Button { bindings.tint.wrappedValue = tint } label: {
                    Circle()
                        .fill(tint.background(dark: dark))
                        .overlay(Circle().strokeBorder(
                            comp.tint == tint ? tint.indicator(dark: dark) : tint.border(dark: dark),
                            lineWidth: comp.tint == tint ? 2.5 : 0.5
                        ))
                        .frame(height: 28)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(Text(L.Editor.color) + Text(verbatim: " \(index + 1)"))
                .accessibilityAddTraits(comp.tint == tint ? .isSelected : [])
            }
        }
        .padding(.bottom, 18)

        SectionLabel(L.Editor.flags)
        Panel(cornerRadius: 16, padding: 0) {
            VStack(spacing: 0) {
                flagRow(L.Editor.track,                  dot: Color(.accent, scheme: colorScheme), isOn: bindings.follow)
                Hairline()
                flagRow(L.domain(lingo.eliminationLabel),   dot: Color(.warning, scheme: colorScheme), isOn: bindings.dispose)
                Hairline()
                flagRow(L.domain(lingo.intakeLabel),        dot: Color(.success, scheme: colorScheme), isOn: bindings.intake)
                if bindings.intake.wrappedValue {
                    Hairline()
                    HStack(spacing: 10) {
                        Circle().fill(Color(.success, scheme: colorScheme).opacity(0.4)).frame(width: 9, height: 9)
                        Text(L.Editor.fraction).font(TypeToken.body)
                        FieldText("0", text: bindings.fractionText, keyboard: .decimal, onEndEditing: onEndNumberEditing)
                            .accessibilityLabel(Text(L.Editor.fraction))
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                }
            }
        }
        .padding(.bottom, 14)

        SectionLabel(L.domain(lingo.substanceName))
        if nuclides.count > 1 {
            RadioList(
                selection: bindings.nuclideId,
                options: nuclides.map { n in
                    ChoiceOption(
                        n.id,
                        title: LocalizedStringKey(n.name),
                        detail: n.halfLife > 0
                            ? (Text(L.domain(lingo.halfLifeLabel)) + Text(verbatim: " \(n.halfLifeText) ") + Text(L.domain(units.time.symbol)))
                            : nil
                    )
                }
            )
        } else if let n = nuclides.first(where: { $0.id == bindings.nuclideId.wrappedValue }) {
            Panel(cornerRadius: 12, padding: 0) {
                HStack {
                    Text(n.name).font(TypeToken.body)
                    Spacer()
                    if n.halfLife > 0 {
                        (Text(L.domain(lingo.halfLifeLabel)) + Text(verbatim: " \(n.halfLifeText) ") + Text(L.domain(units.time.symbol)))
                            .font(TypeToken.codeSmall)
                            .foregroundStyle(.inkMuted)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private func compartmentRelationships(_ comp: EditorFeature.CompartmentRow) -> some View {
        let outbound = links.filter { $0.fromId == comp.id }
        let inbound  = links.filter { $0.toId   == comp.id }

        transferGroup(L.Editor.outbound, links: outbound, direction: .forward)
        transferGroup(L.Editor.inbound,  links: inbound,  direction: .backward)

        Button {
            onBeginTransfer(comp.id, nil)
        } label: {
            Label(L.Editor.addTransfer, systemImage: "plus.circle")
                .font(TypeToken.bodyStrong)
                .foregroundStyle(Color(.accent, scheme: colorScheme))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func transferGroup(
        _ title: LocalizedStringKey,
        links groupLinks: [EditorFeature.LinkRow],
        direction: ArrowDirection
    ) -> some View {
        if !groupLinks.isEmpty {
            SectionLabel(title)
            Panel(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(groupLinks.enumerated()), id: \.1.id) { idx, link in
                        if idx > 0 { Hairline() }
                        linkRelRow(link: link, direction: direction)
                    }
                }
            }
            .padding(.bottom, 14)
        }
    }

    private func linkRelRow(
        link: EditorFeature.LinkRow,
        direction: ArrowDirection
    ) -> some View {
        HStack(spacing: 10) {
            Text("K\(link.id + 1)")
                .font(TypeToken.codeSmall.weight(.semibold))
                .foregroundStyle(link.fromTint.indicator(dark: dark))
                .frame(width: 28, alignment: .leading)
            Image(systemName: direction == .forward ? "arrow.forward" : "arrow.backward")
                .font(TypeToken.sectionLabel.weight(.regular))
                .foregroundStyle(.inkMuted)
            let otherName = direction == .forward ? link.toName : link.fromName
            let otherTint = direction == .forward ? link.toTint  : link.fromTint
            HStack(spacing: 5) {
                Circle()
                    .fill(otherTint.background(dark: dark))
                    .overlay(Circle().strokeBorder(otherTint.border(dark: dark), lineWidth: 0.5))
                    .frame(width: 12, height: 12)
                Text(otherName).font(TypeToken.detail).lineLimit(1)
            }
            Spacer()
            Text(verbatim: link.rateText)
                .font(TypeToken.codeSmall)
                .foregroundStyle(.inkFaint)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { onEditLink(link.id) }
    }

    // MARK: - Link inspector

    @ViewBuilder
    private func linkInspector(
        _ link: EditorFeature.LinkRow,
        bindings: LinkFieldBindings,
        tab: EditorFeature.InspectorTab
    ) -> some View {
        inspectorHead(branch: true, title: Text(verbatim: "K\(link.id + 1)"),
                      sub: Text(verbatim: "\(link.fromName) → \(link.toName)"))

        switch tab {
        case .details:       linkDetails(link, bindings: bindings)
        case .relationships: linkRelationships(link)
        }
    }

    @ViewBuilder
    private func linkDetails(
        _ link: EditorFeature.LinkRow,
        bindings: LinkFieldBindings
    ) -> some View {
        SectionLabel(L.Editor.rateWithUnit(L.domainString(units.rate.symbol)))
        FieldText(L.Editor.rate, text: bindings.rateText, keyboard: .decimal, isMonospaced: true, onEndEditing: onEndNumberEditing)
            .padding(.bottom, 18)

        SectionLabel(L.Editor.endpoints)
        Panel(cornerRadius: 16, padding: 0) {
            VStack(spacing: 0) {
                endpointRow(name: link.fromName, tint: link.fromTint, label: L.Editor.from) {
                    onEditCompartment(link.fromId)
                }
                Hairline()
                endpointRow(name: link.toName, tint: link.toTint, label: L.Editor.to) {
                    onEditCompartment(link.toId)
                }
            }
        }

        deleteButton(label: L.Editor.deleteTransfer) { onDeleteSelected() }
    }

    @ViewBuilder
    private func linkRelationships(_ link: EditorFeature.LinkRow) -> some View {
        SectionLabel(L.Editor.reverseTransfer)
        let reverse = links.first { $0.fromId == link.toId && $0.toId == link.fromId }
        if let rev = reverse {
            Panel(cornerRadius: 12, padding: 0) {
                HStack {
                    Text(verbatim: "K\(rev.ordinalText) · \(rev.rateText)")
                        .font(TypeToken.codeSmall)
                        .foregroundStyle(Color(.ink, scheme: colorScheme))
                    Spacer()
                    Button(L.Editor.jump) { onEditLink(rev.id) }
                        .font(.caption)
                        .foregroundStyle(Color(.accent, scheme: colorScheme))
                        .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        } else {
            Button {
                onBeginTransfer(link.toId, link.fromId)
            } label: {
                Label(L.Editor.addReverseTransfer, systemImage: "plus.circle")
                    .font(TypeToken.bodyStrong)
                    .foregroundStyle(Color(.accent, scheme: colorScheme))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Shared helpers

    @ViewBuilder
    private func inspectorHead(
        swatch: CompartmentTint? = nil,
        branch: Bool = false,
        title: Text,
        sub: Text
    ) -> some View {
        HStack(spacing: 12) {
            if let swatch {
                Circle()
                    .fill(swatch.background(dark: dark))
                    .overlay(Circle().strokeBorder(swatch.border(dark: dark), lineWidth: 1))
                    .frame(width: 34, height: 34)
            } else if branch {
                Image(systemName: "arrow.triangle.branch").font(.title2).foregroundStyle(.inkMuted)
            }
            VStack(alignment: .leading, spacing: 1) {
                title.font(TypeToken.title)
                sub.font(TypeToken.detail).foregroundStyle(Color(.inkFaint, scheme: colorScheme))
            }
            Spacer()
        }
        .padding(.bottom, 16)
    }

    // Binding<Bool> is passed in directly — no inline get/set needed in the pure view.
    private func flagRow(_ label: LocalizedStringKey, dot: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Circle().fill(dot).frame(width: 9, height: 9)
            ToggleSwitch(label, isOn: isOn)
        }
        .padding(.horizontal, 15)
    }

    @ViewBuilder
    private func endpointRow(
        name: String, tint: CompartmentTint, label: LocalizedStringKey, onTap: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.weight(.medium)).foregroundStyle(.inkMuted)
                .frame(width: 28, alignment: .leading)
            HStack(spacing: 6) {
                Circle()
                    .fill(tint.background(dark: dark))
                    .overlay(Circle().strokeBorder(tint.border(dark: dark), lineWidth: 0.5))
                    .frame(width: 14, height: 14)
                Text(name).font(TypeToken.detail)
            }
            Spacer()
            Image(systemName: "chevron.forward").font(.caption2).foregroundStyle(.inkFaint)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private func deleteButton(label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label(label, systemImage: "trash").font(TypeToken.bodyStrong)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 24)
    }
}

private enum ArrowDirection { case forward, backward }

/// The model's backdrop: its field's (automatic), or one of its own, as tiles.
struct BackdropPicker: View {
    @Binding var selection: EditorBackdrop?
    let fieldDefault: EditorBackdrop

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: Space.small)], spacing: Space.small) {
            tile(title: L.Common.automatic, backdrop: fieldDefault, value: nil)
            ForEach(EditorBackdrop.allCases, id: \.self) { backdrop in
                tile(title: L.domain(backdrop.title), backdrop: backdrop, value: backdrop)
            }
        }
    }

    func tile(title: LocalizedStringKey, backdrop: EditorBackdrop, value: EditorBackdrop?) -> some View {
        Button { selection = value } label: {
            Tag(title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .bottomLeading)
                .padding(Space.extraSmall)
                .background { Backdrop(backdrop.style) }
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .strokeBorder(TokenColor(selection == value ? .accent : .hairline), lineWidth: selection == value ? 2.5 : 0.5)
                }
                .contentShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == value ? .isSelected : [])
    }
}

/// The inspector's pages, as their segments show them.
extension EditorFeature.InspectorTab: PageKind {
    public var icon: Image {
        switch self {
        case .details: Image(systemName: "slider.horizontal.3")
        case .relationships: Image(systemName: "arrow.triangle.branch")
        }
    }

    public var title: LocalizedStringKey {
        switch self {
        case .details: L.Editor.details
        case .relationships: L.Editor.relationships
        }
    }
}
