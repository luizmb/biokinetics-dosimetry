import AppDomain
import SwiftUI

// MARK: - InspectorPanel

/// Right panel: tabbed inspector showing Details and Relationships for the
/// currently selected compartment or link.
struct InspectorPanel: View {
    let viewModel: EditorFeature.ViewModel
    @Environment(\.colorScheme) private var colorScheme
    private var dark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            // Xcode-style tab picker
            Picker("Inspector", selection: Binding(
                get: { viewModel.inspectorTab },
                set: { viewModel.dispatch(.setInspectorTab($0)) }
            )) {
                Text("Details").tag(EditorFeature.InspectorTab.details)
                Text("Relationships").tag(EditorFeature.InspectorTab.relationships)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                if let id = viewModel.selectedCompartmentId,
                   let comp = viewModel.compartments.first(where: { $0.id == id }) {
                    compartmentInspector(comp: comp)
                } else if let idx = viewModel.selectedLinkIndex,
                          idx < viewModel.links.count {
                    linkInspector(link: viewModel.links[idx])
                } else {
                    emptyState
                }
            }
        }
        .background(Color.platformGroupedBackground)
    }

    // MARK: - Compartment Inspector

    @ViewBuilder
    private func compartmentInspector(comp: EditorFeature.ViewModel.CompartmentRow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Circle()
                    .fill(comp.tint.fillColor(dark: dark))
                    .overlay(Circle().strokeBorder(comp.tint.strokeColor(dark: dark), lineWidth: 0.5))
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(comp.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text("Compartment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            switch viewModel.inspectorTab {
            case .details:
                compartmentDetails(comp: comp)
            case .relationships:
                compartmentRelationships(comp: comp)
            }
        }
    }

    @ViewBuilder
    private func compartmentDetails(comp: EditorFeature.ViewModel.CompartmentRow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Name field
            infoSection("Name") {
                TextField("Name", text: Binding(
                    get: { comp.name },
                    set: { viewModel.dispatch(.updateCompartmentName(id: comp.id, name: $0)) }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
            }

            // Color tints
            infoSection("Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(CompartmentTint.allCases, id: \.self) { tint in
                        Circle()
                            .fill(tint.fillColor(dark: dark))
                            .overlay(Circle().strokeBorder(
                                comp.tint == tint ? tint.badgeColor(dark: dark) : tint.strokeColor(dark: dark),
                                lineWidth: comp.tint == tint ? 2 : 0.5
                            ))
                            .frame(height: 28)
                    }
                }
            }

            // Flags
            infoSection("Flags") {
                VStack(spacing: 0) {
                    flagRow(label: "Track", color: .blue, value: comp.follow) {
                        viewModel.dispatch(.updateCompartmentFollow(id: comp.id, value: !comp.follow))
                    }
                    Divider()
                    flagRow(label: "Elimination", color: .orange, value: comp.dispose) {
                        viewModel.dispatch(.updateCompartmentDispose(id: comp.id, value: !comp.dispose))
                    }
                    Divider()
                    flagRow(label: "Intake", color: .green, value: comp.intake) {
                        viewModel.dispatch(.updateCompartmentIntake(id: comp.id, value: !comp.intake))
                    }
                }
                .background(Color.platformSecondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator, lineWidth: 0.5))
            }

            // Nuclide picker — only shown when the model has more than one nuclide
            if viewModel.nuclides.count > 1 {
                infoSection("Nuclide") {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.nuclides.enumerated()), id: \.1.id) { idx, nuclide in
                            let isSelected = comp.nuclideId == nuclide.id
                            HStack(spacing: 10) {
                                Image(systemName: isSelected ? "circle.fill" : "circle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(nuclide.name)
                                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                    if nuclide.halfLife > 0 {
                                        Text("T½ \(nuclide.halfLife.formatted(.number.precision(.fractionLength(2)))) d")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.dispatch(.setCompartmentNuclide(compartmentId: comp.id, nuclideId: nuclide.id))
                            }
                            if idx < viewModel.nuclides.count - 1 { Divider() }
                        }
                    }
                    .background(Color.platformSecondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator, lineWidth: 0.5))
                }
            }
        }
    }

    @ViewBuilder
    private func compartmentRelationships(comp: EditorFeature.ViewModel.CompartmentRow) -> some View {
        let outbound = viewModel.links.filter { $0.fromId == comp.id }
        let inbound  = viewModel.links.filter { $0.toId   == comp.id }

        VStack(alignment: .leading, spacing: 0) {
            relationshipSection("Outbound", links: outbound, direction: .forward)
            relationshipSection("Inbound",  links: inbound,  direction: .backward)

            Button {
                viewModel.dispatch(.beginLinking)
            } label: {
                Label("Add transfer", systemImage: "plus.circle")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func relationshipSection(
        _ title: String,
        links: [EditorFeature.ViewModel.LinkRow],
        direction: ArrowDirection
    ) -> some View {
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                VStack(spacing: 0) {
                    ForEach(Array(links.enumerated()), id: \.1.id) { idx, link in
                        if idx > 0 { Divider() }
                        linkRelRow(link: link, direction: direction)
                    }
                }
                .background(Color.platformSecondaryGroupedBackground,
                             in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator, lineWidth: 0.5))
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private func linkRelRow(
        link: EditorFeature.ViewModel.LinkRow,
        direction: ArrowDirection
    ) -> some View {
        HStack(spacing: 10) {
            Text("K\(link.id + 1)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(link.fromTint.badgeColor(dark: dark))
                .frame(width: 28, alignment: .leading)

            Image(systemName: direction == .forward ? "arrow.forward" : "arrow.backward")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            let otherName = direction == .forward ? link.toName : link.fromName
            let otherTint = direction == .forward ? link.toTint  : link.fromTint
            HStack(spacing: 5) {
                Circle()
                    .fill(otherTint.fillColor(dark: dark))
                    .overlay(Circle().strokeBorder(otherTint.strokeColor(dark: dark), lineWidth: 0.5))
                    .frame(width: 12, height: 12)
                Text(otherName)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            Spacer()
            Text(link.rate.scientificString)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.dispatch(.selectLink(link.id)) }
    }

    // MARK: - Link Inspector

    @ViewBuilder
    private func linkInspector(link: EditorFeature.ViewModel.LinkRow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("K\(link.id + 1)")
                        .font(.headline)
                    Text("\(link.fromName) → \(link.toName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            switch viewModel.inspectorTab {
            case .details:
                linkDetails(link: link)
            case .relationships:
                linkRelationships(link: link)
            }
        }
    }

    @ViewBuilder
    private func linkDetails(link: EditorFeature.ViewModel.LinkRow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            infoSection("Rate (day⁻¹)") {
                TextField("Rate", value: Binding(
                    get: { link.rate },
                    set: { viewModel.dispatch(.updateLinkRate(index: link.id, rate: $0)) }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))
                .decimalKeyboard()
            }

            infoSection("Endpoints") {
                VStack(spacing: 0) {
                    endpointRow(name: link.fromName, tint: link.fromTint, label: "From") {
                        viewModel.dispatch(.selectCompartment(link.fromId))
                    }
                    Divider()
                    endpointRow(name: link.toName, tint: link.toTint, label: "To") {
                        viewModel.dispatch(.selectCompartment(link.toId))
                    }
                }
                .background(Color.platformSecondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator, lineWidth: 0.5))
            }
        }
    }

    @ViewBuilder
    private func linkRelationships(link: EditorFeature.ViewModel.LinkRow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Reverse link if exists
            let reverse = viewModel.links.first { $0.fromId == link.toId && $0.toId == link.fromId }
            infoSection("Reverse transfer") {
                if let rev = reverse {
                    HStack {
                        Text("K\(rev.id + 1) · \(rev.rate.scientificString)")
                            .font(.system(size: 12, design: .monospaced))
                        Spacer()
                        Button("Jump") { viewModel.dispatch(.selectLink(rev.id)) }
                            .font(.caption)
                    }
                    .padding(10)
                    .background(Color.platformSecondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator, lineWidth: 0.5))
                } else {
                    Button {
                        viewModel.dispatch(.beginLinking)
                    } label: {
                        Label("Add reverse transfer", systemImage: "plus.circle")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    // MARK: - Shared components

    @ViewBuilder
    private func endpointRow(
        name: String,
        tint: CompartmentTint,
        label: String,
        onTap: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
            HStack(spacing: 6) {
                Circle()
                    .fill(tint.fillColor(dark: dark))
                    .overlay(Circle().strokeBorder(tint.strokeColor(dark: dark), lineWidth: 0.5))
                    .frame(width: 14, height: 14)
                Text(name).font(.system(size: 13))
            }
            Spacer()
            Image(systemName: "chevron.forward")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private func flagRow(
        label: String,
        color: Color,
        value: Bool,
        onToggle: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color.opacity(0.7)).frame(width: 8, height: 8)
            Text(label).font(.system(size: 13))
            Spacer()
            Toggle("", isOn: Binding(get: { value }, set: { _ in onToggle() }))
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func infoSection(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            content()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Document properties header
            HStack {
                Image(systemName: "doc.text")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.documentName)
                        .font(.headline)
                        .lineLimit(1)
                    Text("Document")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            // Nuclide management section
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    infoSection("Nuclides") {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.nuclides.enumerated()), id: \.1.id) { idx, nuclide in
                                nuclideEditorRow(nuclide: nuclide)
                                if idx < viewModel.nuclides.count - 1 { Divider() }
                            }
                            if viewModel.nuclides.isEmpty {
                                Text("No nuclides — tap + to add one")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .background(Color.platformSecondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator, lineWidth: 0.5))
                    }

                    Button {
                        viewModel.dispatch(.addNuclide)
                    } label: {
                        Label("Add nuclide", systemImage: "plus.circle")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                }
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func nuclideEditorRow(nuclide: EditorFeature.ViewModel.NuclideRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("Name", text: Binding(
                    get: { nuclide.name },
                    set: { viewModel.dispatch(.updateNuclideName(id: nuclide.id, name: $0)) }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, weight: .semibold))

                if nuclide.canDelete {
                    Button(role: .destructive) {
                        viewModel.dispatch(.deleteNuclide(id: nuclide.id))
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 6) {
                Text("T½")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("0", value: Binding(
                    get: { nuclide.halfLife },
                    set: { viewModel.dispatch(.updateNuclideHalfLife(id: nuclide.id, halfLife: $0)) }
                ), format: .number.precision(.fractionLength(4)))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .decimalKeyboard()
                Text("days")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if nuclide.compartmentCount > 0 {
                Text("\(nuclide.compartmentCount) compartment\(nuclide.compartmentCount == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Supporting types

private enum ArrowDirection { case forward, backward }
