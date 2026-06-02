import AppDomain
import Domain
import SwiftUI
import UIComponents

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
    let lingo: FieldLingo
    let nuclides:             [EditorFeature.ViewModel.NuclideRow]
    let compartments:         [EditorFeature.ViewModel.CompartmentRow]
    let links:                [EditorFeature.ViewModel.LinkRow]
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
    @Environment(\.glassTokens) private var g
    private var dark: Bool { colorScheme == .dark }

    private var selectedComp: EditorFeature.ViewModel.CompartmentRow? {
        compartments.first { $0.id == selectedCompartmentId }
    }
    private var selectedLink: EditorFeature.ViewModel.LinkRow? {
        selectedLinkIndex.flatMap { idx in links.first { $0.id == idx } }
    }

    var body: some View {
        VStack(spacing: 0) {
            if selectedComp != nil || selectedLink != nil {
                GSegmented(
                    selection: $inspectorTab,
                    options: [
                        ("Details",       EditorFeature.InspectorTab.details),
                        ("Relationships", EditorFeature.InspectorTab.relationships),
                    ]
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                GlassDivider()
            } else {
                HStack {
                    Text("INSPECTOR")
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(0.5)
                        .foregroundStyle(g.faint)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)
                GlassDivider()
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
        _ comp: EditorFeature.ViewModel.CompartmentRow,
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
        _ comp: EditorFeature.ViewModel.CompartmentRow,
        bindings: CompartmentFieldBindings
    ) -> some View {
        GLabel("Name")
        GCard(cornerRadius: 12, intensity: 0.5) {
            TextField("Name", text: bindings.name)
                .padding(.horizontal, 14)
                .frame(height: 44)
        }
        .padding(.bottom, 18)

        GLabel("Color")
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

        GLabel("Flags")
        GCard(cornerRadius: 16, intensity: 0.5) {
            VStack(spacing: 0) {
                flagRow("Track",                  dot: Color(hex: 0x3B9BFF), isOn: bindings.follow)
                GlassDivider()
                flagRow(lingo.eliminationLabel,   dot: Color(hex: 0xF59E0B), isOn: bindings.dispose)
                GlassDivider()
                flagRow(lingo.intakeLabel,        dot: Color(hex: 0x34C759), isOn: bindings.intake)
                if bindings.intake.wrappedValue {
                    GlassDivider()
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: 0x34C759).opacity(0.4)).frame(width: 9, height: 9)
                        Text("Fraction (0–1)").font(.system(size: 16))
                        Spacer()
                        TextField("0", value: bindings.fraction, format: .number.precision(.fractionLength(6)))
                            .font(.system(size: 15, design: .monospaced))
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

        GLabel(lingo.substanceName)
        if nuclides.count > 1 {
            GRadioList(
                selection: bindings.nuclideId,
                options: nuclides.map { n in
                    GRadioOption(value: n.id, label: n.name,
                                 detail: n.halfLife > 0 ? "\(lingo.halfLifeLabel) \(n.halfLife.formatted(.number.precision(.fractionLength(2)))) \(lingo.timeUnit.label)" : nil)
                }
            )
        } else if let n = nuclides.first(where: { $0.id == bindings.nuclideId.wrappedValue }) {
            GCard(cornerRadius: 12, intensity: 0.5) {
                HStack {
                    Text(n.name).font(.system(size: 15))
                    Spacer()
                    if n.halfLife > 0 {
                        Text("\(lingo.halfLifeLabel) \(n.halfLife.formatted(.number.precision(.fractionLength(2)))) \(lingo.timeUnit.label)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private func compartmentRelationships(_ comp: EditorFeature.ViewModel.CompartmentRow) -> some View {
        let outbound = links.filter { $0.fromId == comp.id }
        let inbound  = links.filter { $0.toId   == comp.id }

        transferGroup("Outbound", links: outbound, direction: .forward)
        transferGroup("Inbound",  links: inbound,  direction: .backward)

        Button {
            onBeginLinking()
        } label: {
            Label("Add transfer", systemImage: "plus.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(g.accent)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func transferGroup(
        _ title: String,
        links groupLinks: [EditorFeature.ViewModel.LinkRow],
        direction: ArrowDirection
    ) -> some View {
        if !groupLinks.isEmpty {
            GLabel(title)
            GCard(cornerRadius: 16, intensity: 0.5) {
                VStack(spacing: 0) {
                    ForEach(Array(groupLinks.enumerated()), id: \.1.id) { idx, link in
                        if idx > 0 { GlassDivider() }
                        linkRelRow(link: link, direction: direction)
                    }
                }
            }
            .padding(.bottom, 14)
        }
    }

    private func linkRelRow(
        link: EditorFeature.ViewModel.LinkRow,
        direction: ArrowDirection
    ) -> some View {
        HStack(spacing: 10) {
            Text("K\(link.id + 1)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(link.fromTint.indicator(dark: dark))
                .frame(width: 28, alignment: .leading)
            Image(systemName: direction == .forward ? "arrow.forward" : "arrow.backward")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            let otherName = direction == .forward ? link.toName : link.fromName
            let otherTint = direction == .forward ? link.toTint  : link.fromTint
            HStack(spacing: 5) {
                Circle()
                    .fill(otherTint.background(dark: dark))
                    .overlay(Circle().strokeBorder(otherTint.border(dark: dark), lineWidth: 0.5))
                    .frame(width: 12, height: 12)
                Text(otherName).font(.system(size: 12)).lineLimit(1)
            }
            Spacer()
            Text(link.rate.scientificString)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { onSelectLink(link.id) }
    }

    // MARK: - Link inspector

    @ViewBuilder
    private func linkInspector(
        _ link: EditorFeature.ViewModel.LinkRow,
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
        _ link: EditorFeature.ViewModel.LinkRow,
        bindings: LinkFieldBindings
    ) -> some View {
        GLabel("Rate (\(lingo.rateUnit))")
        GCard(cornerRadius: 12, intensity: 0.5) {
            TextField("Rate", value: bindings.rate, format: .number)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .font(.system(size: 16, design: .monospaced))
                .decimalKeyboard()
        }
        .padding(.bottom, 18)

        GLabel("Endpoints")
        GCard(cornerRadius: 16, intensity: 0.5) {
            VStack(spacing: 0) {
                endpointRow(name: link.fromName, tint: link.fromTint, label: "From") {
                    onSelectCompartment(link.fromId)
                }
                GlassDivider()
                endpointRow(name: link.toName, tint: link.toTint, label: "To") {
                    onSelectCompartment(link.toId)
                }
            }
        }

        deleteButton(label: "Delete transfer") { onDeleteSelected() }
    }

    @ViewBuilder
    private func linkRelationships(_ link: EditorFeature.ViewModel.LinkRow) -> some View {
        GLabel("Reverse transfer")
        let reverse = links.first { $0.fromId == link.toId && $0.toId == link.fromId }
        if let rev = reverse {
            GCard(cornerRadius: 12, intensity: 0.5) {
                HStack {
                    Text("K\(rev.id + 1) · \(rev.rate.scientificString)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(g.ink)
                    Spacer()
                    Button("Jump") { onSelectLink(rev.id) }
                        .font(.caption)
                        .foregroundStyle(g.accent)
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(g.accent)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Document inspector (empty / no selection)

    private var documentInspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text").font(.title2).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Document").font(.headline)
                    Text("Model properties").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 16)

            GLabel("Name")
            GCard(cornerRadius: 12, intensity: 0.5) {
                TextField("Model name", text: $documentName)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
            }
            .padding(.bottom, 14)

            GLabel("Description")
            GCard(cornerRadius: 12, intensity: 0.5) {
                TextField("Optional description", text: $documentDescription, axis: .vertical)
                    .lineLimit(3...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
            .padding(.bottom, 18)

            if !validationIssues.isEmpty {
                GLabel("Issues")
                GCard(cornerRadius: 16, intensity: 0.5) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(validationIssues.indices, id: \.self) { i in
                            if i > 0 { GlassDivider() }
                            issueRow(validationIssues[i])
                        }
                    }
                }
                .padding(.bottom, 18)
            }

            GLabel("Variants")
            GCard(cornerRadius: 16, intensity: 0.5) {
                VStack(spacing: 0) {
                    variantRow(key: nil, label: "Base model")
                    ForEach(variants, id: \.self) { key in
                        GlassDivider()
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(g.accent)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 18)

            GLabel("Field")
            GCard(cornerRadius: 16, intensity: 0.5) {
                VStack(spacing: 0) {
                    ForEach(Array(ModelField.allCases.enumerated()), id: \.1) { idx, f in
                        if idx > 0 { GlassDivider() }
                        HStack {
                            Text(f.lingo.fieldName).font(.system(size: 15))
                            Spacer()
                            if field == f {
                                Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(g.accent)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .contentShape(Rectangle())
                        .onTapGesture { field = f }
                    }
                }
            }
            .padding(.bottom, 18)

            GLabel(lingo.substancesLabel)
            GCard(cornerRadius: 16, intensity: 0.5) {
                VStack(spacing: 0) {
                    ForEach(Array(nuclideBindings.enumerated()), id: \.1.id) { idx, nb in
                        if idx > 0 { GlassDivider() }
                        nuclideEditorRow(nb)
                    }
                    if nuclideBindings.isEmpty {
                        Text("No nuclides — tap + to add one")
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(12).frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.bottom, 8)

            Button { onAddNuclide() } label: {
                Label("Add \(lingo.substanceName)", systemImage: "plus.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(g.accent)
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
                    .font(.system(size: 15))
                    .submitLabel(.done)
                    .onSubmit { onCommitVariantRename() }
                Button("Done") { onCommitVariantRename() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(g.accent)
                    .buttonStyle(PlainButtonStyle())
                Button { onCancelVariantRename() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
        } else {
            HStack {
                Text(label).font(.system(size: 15))
                Spacer()
                if isEditing {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(g.accent)
                }
                if let key {
                    Button { onBeginVariantRename(key) } label: {
                        Image(systemName: "pencil").font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Button(role: .destructive) { onDeleteVariant(key) } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(isEditing ? g.accent.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { onSelectEditingVariant(key) }
        }
    }

    @ViewBuilder
    private func nuclideEditorRow(_ nb: NuclideEditBinding) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("Name", text: nb.name)
                    .font(.system(size: 13, weight: .semibold))
                if nb.canDelete {
                    Button(role: .destructive) { onDeleteNuclide(nb.id) } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            HStack(spacing: 6) {
                Text(lingo.halfLifeLabel).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                if nb.halfLife.wrappedValue == 0 && !lingo.isHalfLifeRequired {
                    Text("None")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .onTapGesture { nb.halfLife.wrappedValue = 1 }
                } else {
                    TextField("0", value: nb.halfLife, format: .number.precision(.fractionLength(4)))
                        .font(.system(size: 12, design: .monospaced))
                        .decimalKeyboard()
                    Text(lingo.timeUnit.label).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            if nb.compartmentCount > 0 {
                Text("\(nb.compartmentCount) compartment\(nb.compartmentCount == 1 ? "" : "s")")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
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
                Image(systemName: "arrow.triangle.branch").font(.title2).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 21, weight: .bold))
                Text(sub).font(.system(size: 14)).foregroundStyle(g.faint)
            }
            Spacer()
        }
        .padding(.bottom, 16)
    }

    // Binding<Bool> is passed in directly — no inline get/set needed in the pure view.
    private func flagRow(_ label: String, dot: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Circle().fill(dot).frame(width: 9, height: 9)
            Text(label).font(.system(size: 16))
            Spacer()
            GToggle(isOn: isOn)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func endpointRow(
        name: String, tint: CompartmentTint, label: String, onTap: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
            HStack(spacing: 6) {
                Circle()
                    .fill(tint.background(dark: dark))
                    .overlay(Circle().strokeBorder(tint.border(dark: dark), lineWidth: 0.5))
                    .frame(width: 14, height: 14)
                Text(name).font(.system(size: 13))
            }
            Spacer()
            Image(systemName: "chevron.forward").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private func issueRow(_ issue: CompartmentalModel.ValidationIssue) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: issue.systemImageName)
                .font(.system(size: 14))
                .foregroundStyle(issueTint(issue.severity))
                .frame(width: 20)
            Text(issue.issueDescription)
                .font(.system(size: 13))
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
        case .info:    g.muted
        }
    }

    private func deleteButton(label: String, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label(label, systemImage: "trash").font(.system(size: 16, weight: .semibold))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 24)
    }
}

private enum ArrowDirection { case forward, backward }
