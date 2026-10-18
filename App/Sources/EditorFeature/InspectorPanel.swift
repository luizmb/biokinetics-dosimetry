import AppDomain
import Domain
import SwiftUI
import Vitral

// MARK: - Field binding groups
// Created in the @BoundTo container; the pure inspector views just consume them.

struct CompartmentFieldBindings {
    var name:      Binding<String>
    var follow:    Binding<Bool>
    var dispose:   Binding<Bool>
    var intake:    Binding<Bool>
    var fraction:  Binding<Double>
    var nuclideId: Binding<String>
}

struct LinkFieldBindings {
    var rate: Binding<Double>
}

struct NuclideEditBinding {
    var id:             String
    var name:           Binding<String>
    var halfLife:       Binding<Double>
    var canDelete:      Bool
    var compartmentCount: Int
}

// MARK: - EditorInspectorPanel (pure)

struct EditorInspectorPanel: View {
    // Data props (read-only)
    @Binding var documentName: String
    @Binding var documentDescription: String
    @Binding var field: ModelField
    @Binding var backdrop: EditorBackdrop?
    let resolvedBackdrop: EditorBackdrop
    let lingo: FieldLingo
    let nuclides:             [EditorFeature.NuclideRow]
    let compartments:         [EditorFeature.CompartmentRow]
    let links:                [EditorFeature.LinkRow]
    let selectedCompartmentId: String?
    let selectedLinkIndex:    Int?

    // Bidirectional bindings (created by the container, nil when nothing is selected)
    @Binding var inspectorTab:    EditorFeature.InspectorTab
    var compartmentBindings:      CompartmentFieldBindings?
    var linkBindings:             LinkFieldBindings?
    var nuclideBindings:          [NuclideEditBinding]

    let validationIssues: [CompartmentalModel.ValidationIssue]

    // One-way action callbacks (no return value needed)
    var onSelectCompartment: (String?) -> Void
    var onSelectLink:        (Int?) -> Void
    var onBeginLinking:      () -> Void
    var onDeleteSelected:    () -> Void
    var onAddNuclide:        () -> Void
    var onDeleteNuclide:     (String) -> Void
    var onAddVariant:           (String) -> Void
    var onDeleteVariant:        (String) -> Void
    var onSelectEditingVariant: (String?) -> Void
    var onBeginVariantRename:   (String) -> Void
    var onCommitVariantRename:  () -> Void
    var onCancelVariantRename:  () -> Void
    let variants: [String]
    let editingVariant: String?
    let renamingVariant: String?
    @Binding var variantRenameDraft: String

    @Environment(\.colorScheme) private var colorScheme
    private var dark: Bool { colorScheme == .dark }

    private var selectedComp: EditorFeature.CompartmentRow? {
        compartments.first { $0.id == selectedCompartmentId }
    }
    private var selectedLink: EditorFeature.LinkRow? {
        selectedLinkIndex.flatMap { idx in links.first { $0.id == idx } }
    }

    var body: some View {
        VStack(spacing: 0) {
            if selectedComp != nil || selectedLink != nil {
                SegmentedControlGlass(
                    selection: $inspectorTab,
                    options: [
                        ChoiceOption(EditorFeature.InspectorTab.details, title: "Details"),
                        ChoiceOption(EditorFeature.InspectorTab.relationships, title: "Relationships"),
                    ]
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                Hairline()
            } else {
                HStack {
                    Text("INSPECTOR")
                        .font(TypeToken.sectionLabel)
                        .kerning(0.5)
                        .foregroundStyle(Color(.inkFaint))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)
                Hairline()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let comp = selectedComp, let cb = compartmentBindings {
                        compartmentInspector(comp, bindings: cb)
                    } else if let link = selectedLink, let lb = linkBindings {
                        linkInspector(link, bindings: lb)
                    } else {
                        documentInspector
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.platformGroupedBackground)
    }

    // MARK: - Compartment inspector

    @ViewBuilder
    private func compartmentInspector(
        _ comp: EditorFeature.CompartmentRow,
        bindings: CompartmentFieldBindings
    ) -> some View {
        inspectorHead(swatch: comp.tint, title: comp.name, sub: "Compartment")

        switch inspectorTab {
        case .details:       compartmentDetails(comp, bindings: bindings)
        case .relationships: compartmentRelationships(comp)
        }
    }

    @ViewBuilder
    private func compartmentDetails(
        _ comp: EditorFeature.CompartmentRow,
        bindings: CompartmentFieldBindings
    ) -> some View {
        SectionLabel("Name")
        FieldText("Name", text: bindings.name)
        .padding(.bottom, 18)

        SectionLabel("Color")
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
            ForEach(CompartmentTint.allCases, id: \.self) { tint in
                Circle()
                    .fill(tint.background(dark: dark))
                    .overlay(Circle().strokeBorder(
                        comp.tint == tint ? tint.indicator(dark: dark) : tint.border(dark: dark),
                        lineWidth: comp.tint == tint ? 2.5 : 0.5
                    ))
                    .frame(height: 28)
            }
        }
        .padding(.bottom, 18)

        SectionLabel("Flags")
        Panel(cornerRadius: 16, padding: 0) {
            VStack(spacing: 0) {
                flagRow("Track",                  dot: Color(.accent), isOn: bindings.follow)
                Hairline()
                flagRow(lingo.eliminationLabel,   dot: Color(.warning), isOn: bindings.dispose)
                Hairline()
                flagRow(lingo.intakeLabel,        dot: Color(.success), isOn: bindings.intake)
                if bindings.intake.wrappedValue {
                    Hairline()
                    HStack(spacing: 10) {
                        Circle().fill(Color(.success).opacity(0.4)).frame(width: 9, height: 9)
                        Text("Fraction (0–1)").font(TypeToken.body)
                        Spacer()
                        TextField("0", value: bindings.fraction, format: .number.precision(.fractionLength(6)))
                            .font(TypeToken.code)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .decimalKeyboard()
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                }
            }
        }
        .padding(.bottom, 14)

        SectionLabel(LocalizedStringKey(lingo.substanceName))
        if nuclides.count > 1 {
            RadioList(
                selection: bindings.nuclideId,
                options: nuclides.map { n in
                    ChoiceOption(
                        n.id,
                        title: LocalizedStringKey(n.name),
                        detail: n.halfLife > 0
                            ? Text(verbatim: "\(lingo.halfLifeLabel) \(n.halfLife.formatted(.number.precision(.fractionLength(2)))) \(lingo.timeUnit.label)")
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
                        Text("\(lingo.halfLifeLabel) \(n.halfLife.formatted(.number.precision(.fractionLength(2)))) \(lingo.timeUnit.label)")
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

        transferGroup("Outbound", links: outbound, direction: .forward)
        transferGroup("Inbound",  links: inbound,  direction: .backward)

        Button {
            onBeginLinking()
        } label: {
            Label("Add transfer", systemImage: "plus.circle")
                .font(TypeToken.bodyStrong)
                .foregroundStyle(Color(.accent))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func transferGroup(
        _ title: String,
        links groupLinks: [EditorFeature.LinkRow],
        direction: ArrowDirection
    ) -> some View {
        if !groupLinks.isEmpty {
            SectionLabel(LocalizedStringKey(title))
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
            Text(link.rate.scientificString)
                .font(TypeToken.codeSmall)
                .foregroundStyle(.inkFaint)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { onSelectLink(link.id) }
    }

    // MARK: - Link inspector

    @ViewBuilder
    private func linkInspector(
        _ link: EditorFeature.LinkRow,
        bindings: LinkFieldBindings
    ) -> some View {
        inspectorHead(branch: true, title: "K\(link.id + 1)",
                      sub: "\(link.fromName) → \(link.toName)")

        switch inspectorTab {
        case .details:       linkDetails(link, bindings: bindings)
        case .relationships: linkRelationships(link)
        }
    }

    @ViewBuilder
    private func linkDetails(
        _ link: EditorFeature.LinkRow,
        bindings: LinkFieldBindings
    ) -> some View {
        SectionLabel("Rate (\(lingo.rateUnit))")
        FieldContainer {
            TextField("Rate", value: bindings.rate, format: .number)
                .fontDesign(.monospaced)
                .decimalKeyboard()
        }
        .padding(.bottom, 18)

        SectionLabel("Endpoints")
        Panel(cornerRadius: 16, padding: 0) {
            VStack(spacing: 0) {
                endpointRow(name: link.fromName, tint: link.fromTint, label: "From") {
                    onSelectCompartment(link.fromId)
                }
                Hairline()
                endpointRow(name: link.toName, tint: link.toTint, label: "To") {
                    onSelectCompartment(link.toId)
                }
            }
        }

        deleteButton(label: "Delete transfer") { onDeleteSelected() }
    }

    @ViewBuilder
    private func linkRelationships(_ link: EditorFeature.LinkRow) -> some View {
        SectionLabel("Reverse transfer")
        let reverse = links.first { $0.fromId == link.toId && $0.toId == link.fromId }
        if let rev = reverse {
            Panel(cornerRadius: 12, padding: 0) {
                HStack {
                    Text("K\(rev.id + 1) · \(rev.rate.scientificString)")
                        .font(TypeToken.codeSmall)
                        .foregroundStyle(Color(.ink))
                    Spacer()
                    Button("Jump") { onSelectLink(rev.id) }
                        .font(.caption)
                        .foregroundStyle(Color(.accent))
                        .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        } else {
            Button {
                onBeginLinking()
            } label: {
                Label("Add reverse transfer", systemImage: "plus.circle")
                    .font(TypeToken.bodyStrong)
                    .foregroundStyle(Color(.accent))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Document inspector (empty / no selection)

    private var documentInspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text").font(.title2).foregroundStyle(.inkMuted)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Document").font(.headline)
                    Text("Model properties").font(.caption).foregroundStyle(.inkMuted)
                }
            }
            .padding(.bottom, 16)

            SectionLabel("Name")
            FieldText("Model name", text: $documentName)
            .padding(.bottom, 14)

            SectionLabel("Description")
            FieldContainer {
                TextField("Optional description", text: $documentDescription, axis: .vertical)
                    .lineLimit(3...5)
                    .padding(.vertical, Space.small)
            }
            .padding(.bottom, 18)

            if !validationIssues.isEmpty {
                SectionLabel("Issues")
                Panel(cornerRadius: 16, padding: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(validationIssues.indices, id: \.self) { i in
                            if i > 0 { Hairline() }
                            issueRow(validationIssues[i])
                        }
                    }
                }
                .padding(.bottom, 18)
            }

            SectionLabel("Variants")
            Panel(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    variantRow(key: nil, label: "Base model")
                    ForEach(variants, id: \.self) { key in
                        Hairline()
                        variantRow(key: key, label: key)
                    }
                }
            }
            .padding(.bottom, 8)

            Button {
                let name = "Variant \(variants.count + 1)"
                onAddVariant(name)
            } label: {
                Label("Add variant", systemImage: "plus.circle")
                    .font(TypeToken.bodyStrong)
                    .foregroundStyle(Color(.accent))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 18)

            SectionLabel("Field")
            Panel(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(ModelField.allCases.enumerated()), id: \.1) { idx, f in
                        if idx > 0 { Hairline() }
                        HStack {
                            Text(f.lingo.fieldName).font(TypeToken.body)
                            Spacer()
                            if field == f {
                                Image(systemName: "checkmark").font(TypeToken.detail.weight(.semibold))
                                    .foregroundStyle(Color(.accent))
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .contentShape(Rectangle())
                        .onTapGesture { field = f }
                    }
                }
            }
            .padding(.bottom, 18)

            SectionLabel("Backdrop")
            BackdropPicker(selection: $backdrop, fieldDefault: field.backdrop)
                .padding(.bottom, 18)

            SectionLabel(LocalizedStringKey(lingo.substancesLabel))
            Panel(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(nuclideBindings.enumerated()), id: \.1.id) { idx, nb in
                        if idx > 0 { Hairline() }
                        nuclideEditorRow(nb)
                    }
                    if nuclideBindings.isEmpty {
                        Text("No nuclides — tap + to add one")
                            .font(.caption).foregroundStyle(.inkMuted)
                            .padding(12).frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.bottom, 8)

            Button { onAddNuclide() } label: {
                Label("Add \(lingo.substanceName)", systemImage: "plus.circle")
                    .font(TypeToken.bodyStrong)
                    .foregroundStyle(Color(.accent))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    @ViewBuilder
    private func variantRow(key: String?, label: String) -> some View {
        let isEditing  = editingVariant == key
        let isRenaming = key != nil && renamingVariant == key

        if isRenaming {
            HStack(spacing: 8) {
                TextField("Variant name", text: $variantRenameDraft)
                    .font(TypeToken.body)
                    .submitLabel(.done)
                    .onSubmit { onCommitVariantRename() }
                Button("Done") { onCommitVariantRename() }
                    .font(TypeToken.detail.weight(.semibold))
                    .foregroundStyle(Color(.accent))
                    .buttonStyle(PlainButtonStyle())
                Button { onCancelVariantRename() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.inkMuted)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
        } else {
            HStack {
                Text(label).font(TypeToken.body)
                Spacer()
                if isEditing {
                    Image(systemName: "pencil.circle.fill")
                        .font(TypeToken.detail.weight(.semibold))
                        .foregroundStyle(Color(.accent))
                }
                if let key {
                    Button { onBeginVariantRename(key) } label: {
                        Image(systemName: "pencil").font(TypeToken.detail)
                            .foregroundStyle(.inkMuted)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Button(role: .destructive) { onDeleteVariant(key) } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.danger)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(isEditing ? Color(.accent).opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { onSelectEditingVariant(key) }
        }
    }

    @ViewBuilder
    private func nuclideEditorRow(_ nb: NuclideEditBinding) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("Name", text: nb.name)
                    .font(TypeToken.detail.weight(.semibold))
                if nb.canDelete {
                    Button(role: .destructive) { onDeleteNuclide(nb.id) } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.danger)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            HStack(spacing: 6) {
                Text(lingo.halfLifeLabel).font(TypeToken.sectionLabel.weight(.medium)).foregroundStyle(.inkMuted)
                if nb.halfLife.wrappedValue == 0 && !lingo.isHalfLifeRequired {
                    Text("None")
                        .font(TypeToken.codeSmall)
                        .foregroundStyle(.inkFaint)
                        .onTapGesture { nb.halfLife.wrappedValue = 1 }
                } else {
                    TextField("0", value: nb.halfLife, format: .number.precision(.fractionLength(4)))
                        .font(TypeToken.codeSmall)
                        .decimalKeyboard()
                    Text(lingo.timeUnit.label).font(TypeToken.sectionLabel.weight(.regular)).foregroundStyle(.inkMuted)
                }
            }
            if nb.compartmentCount > 0 {
                Text("\(nb.compartmentCount) compartment\(nb.compartmentCount == 1 ? "" : "s")")
                    .font(TypeToken.sectionLabel.weight(.regular)).foregroundStyle(.inkFaint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Shared helpers

    @ViewBuilder
    private func inspectorHead(
        swatch: CompartmentTint? = nil,
        branch: Bool = false,
        title: String,
        sub: String
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
                Text(title).font(TypeToken.title)
                Text(sub).font(TypeToken.detail).foregroundStyle(Color(.inkFaint))
            }
            Spacer()
        }
        .padding(.bottom, 16)
    }

    // Binding<Bool> is passed in directly — no inline get/set needed in the pure view.
    private func flagRow(_ label: String, dot: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Circle().fill(dot).frame(width: 9, height: 9)
            ToggleSwitch(LocalizedStringKey(label), isOn: isOn)
        }
        .padding(.horizontal, 15)
    }

    @ViewBuilder
    private func endpointRow(
        name: String, tint: CompartmentTint, label: String, onTap: @escaping () -> Void
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

    private func issueRow(_ issue: CompartmentalModel.ValidationIssue) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: issue.systemImageName)
                .font(TypeToken.detail)
                .foregroundStyle(issueTint(issue.severity))
                .frame(width: 20)
            Text(issue.issueDescription)
                .font(TypeToken.detail)
                .foregroundStyle(issueTint(issue.severity))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func issueTint(_ severity: CompartmentalModel.ValidationIssue.Severity) -> Color {
        switch severity {
        case .error:   .orange
        case .warning: dark ? .yellow : Color(hue: 0.12, saturation: 0.8, brightness: 0.6)
        case .info:    Color(.inkMuted)
        }
    }

    private func deleteButton(label: String, action: @escaping () -> Void) -> some View {
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
            tile(title: "Automatic", backdrop: fieldDefault, value: nil)
            ForEach(EditorBackdrop.allCases, id: \.self) { backdrop in
                tile(title: LocalizedStringKey(backdrop.title), backdrop: backdrop, value: backdrop)
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
                        .strokeBorder(Color(selection == value ? .accent : .hairline), lineWidth: selection == value ? 2.5 : 0.5)
                }
                .contentShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == value ? .isSelected : [])
    }
}
