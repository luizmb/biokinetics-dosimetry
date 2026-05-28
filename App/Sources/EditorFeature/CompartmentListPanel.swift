import AppDomain
import SwiftUI

// MARK: - CompartmentListPanel

/// Left sidebar: scrollable list of compartments and links, with a delete
/// button anchored at the bottom when something is selected.
struct CompartmentListPanel: View {
    let viewModel: EditorFeature.ViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Model")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 4)

            Divider()

            ScrollViewReader { proxy in
                List {
                    if viewModel.nuclides.count > 1 {
                        // Multi-nuclide: group compartments under each nuclide
                        ForEach(viewModel.nuclides) { nuclide in
                            let comps = viewModel.compartments.filter { $0.nuclideId == nuclide.id }
                            Section {
                                ForEach(comps) { comp in
                                    compartmentRow(comp: comp, proxy: proxy)
                                }
                            } header: {
                                nuclideHeader(nuclide: nuclide)
                            }
                        }
                    } else {
                        // Single-nuclide: flat list
                        Section {
                            ForEach(viewModel.compartments) { comp in
                                compartmentRow(comp: comp, proxy: proxy)
                            }
                        } header: {
                            Text("Compartments")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Links section
                    Section {
                        ForEach(viewModel.links) { link in
                            linkRow(link: link)
                        }
                    } header: {
                        Text("Transfers")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .onChange(of: viewModel.selectedCompartmentId) { _, id in
                    if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                }
                .onChange(of: viewModel.selectedLinkIndex) { _, idx in
                    if let idx { withAnimation { proxy.scrollTo("link-\(idx)", anchor: .center) } }
                }
            }

            // Delete footer
            if viewModel.selectedCompartmentId != nil || viewModel.selectedLinkIndex != nil {
                Divider()
                deleteFooter
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.platformGroupedBackground)
        .animation(.spring(response: 0.2, dampingFraction: 0.9),
                   value: viewModel.selectedCompartmentId)
        .animation(.spring(response: 0.2, dampingFraction: 0.9),
                   value: viewModel.selectedLinkIndex)
    }

    // MARK: - Nuclide section header

    @ViewBuilder
    private func nuclideHeader(nuclide: EditorFeature.ViewModel.NuclideRow) -> some View {
        HStack(spacing: 4) {
            Text(nuclide.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if nuclide.halfLife > 0 {
                Text("· T½ \(nuclide.halfLife.formatted(.number.precision(.fractionLength(1)))) d")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func compartmentRow(
        comp: EditorFeature.ViewModel.CompartmentRow,
        proxy: ScrollViewProxy
    ) -> some View {
        let isSelected = viewModel.selectedCompartmentId == comp.id
        HStack(spacing: 10) {
            Circle()
                .fill(comp.tint.fillColor(dark: colorScheme == .dark))
                .overlay(Circle().strokeBorder(comp.tint.strokeColor(dark: colorScheme == .dark),
                                               lineWidth: 0.5))
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(comp.name)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                if comp.follow || comp.dispose || comp.intake {
                    HStack(spacing: 4) {
                        if comp.follow  { flagChip("Track") }
                        if comp.dispose { flagChip("Elim") }
                        if comp.intake  { flagChip("Intake") }
                    }
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .listRowBackground(
            isSelected
                ? Color.accentColor.opacity(0.08)
                : Color.clear
        )
        .id(comp.id)
        .onTapGesture { viewModel.dispatch(.selectCompartment(comp.id)) }
    }

    @ViewBuilder
    private func linkRow(link: EditorFeature.ViewModel.LinkRow) -> some View {
        let isSelected = viewModel.selectedLinkIndex == link.id
        HStack(spacing: 8) {
            Image(systemName: "arrow.forward")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text("K\(link.id + 1)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(link.fromTint.badgeColor(dark: colorScheme == .dark))
            Text("\(link.fromName) → \(link.toName)")
                .font(.system(size: 11.5))
                .lineLimit(1)
            Spacer()
            Text(link.rate.scientificString)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .listRowBackground(
            isSelected
                ? Color.accentColor.opacity(0.08)
                : Color.clear
        )
        .id("link-\(link.id)")
        .onTapGesture { viewModel.dispatch(.selectLink(link.id)) }
    }

    // MARK: - Footer

    private var deleteFooter: some View {
        HStack {
            if let id = viewModel.selectedCompartmentId,
               let comp = viewModel.compartments.first(where: { $0.id == id }) {
                Label("Selected · \(comp.name)", systemImage: "square.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if let idx = viewModel.selectedLinkIndex {
                Label("Selected · K\(idx + 1)", systemImage: "arrow.forward")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                if let id = viewModel.selectedCompartmentId {
                    viewModel.dispatch(.deleteCompartment(id: id))
                } else if let idx = viewModel.selectedLinkIndex {
                    viewModel.dispatch(.deleteLink(index: idx))
                }
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func flagChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(.quaternary, in: Capsule())
    }
}

// MARK: - Double formatting

extension Double {
    var scientificString: String {
        let exp = self == 0 ? 0 : Int(floor(log10(abs(self))))
        let m = self == 0 ? 0 : self / pow(10, Double(exp))
        return String(format: "%.2fe%+03d", m, exp)
    }
}
