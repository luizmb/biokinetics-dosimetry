import AppDomain
import SwiftUI
import UIComponents

// MARK: - EditorModelListPanel (pure)

struct EditorModelListPanel: View {
    let nuclides: [EditorFeature.ViewModel.NuclideRow]
    let compartments: [EditorFeature.ViewModel.CompartmentRow]
    let links: [EditorFeature.ViewModel.LinkRow]
    let selectedCompartmentId: String?
    let selectedLinkIndex: Int?
    let selectionFooterLabel: String?
    var onSelectCompartment: (String?) -> Void
    var onSelectLink: (Int?) -> Void
    var onDeleteSelected: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.glassTokens) private var g

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("MODEL")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(g.faint)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            GlassDivider()

            ScrollViewReader { proxy in
                List {
                    if nuclides.count > 1 {
                        ForEach(nuclides) { nuclide in
                            let comps = compartments.filter { $0.nuclideId == nuclide.id }
                            Section {
                                ForEach(comps) { comp in
                                    compartmentRow(comp, proxy: proxy)
                                }
                            } header: {
                                nuclideHeader(nuclide)
                            }
                        }
                    } else {
                        Section {
                            ForEach(compartments) { comp in
                                compartmentRow(comp, proxy: proxy)
                            }
                        } header: {
                            Text("Compartments")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        ForEach(links) { link in
                            linkRow(link)
                        }
                    } header: {
                        Text("Transfers")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .onChange(of: selectedCompartmentId) { _, id in
                    if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                }
                .onChange(of: selectedLinkIndex) { _, idx in
                    if let idx { withAnimation { proxy.scrollTo("link-\(idx)", anchor: .center) } }
                }
            }

            // Delete footer
            if selectionFooterLabel != nil {
                GlassDivider()
                deleteFooter
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.2, dampingFraction: 0.9), value: selectionFooterLabel)
            }
        }
        .background(Color.platformGroupedBackground)
        .animation(.spring(response: 0.2, dampingFraction: 0.9), value: selectionFooterLabel)
    }

    // MARK: - Nuclide header

    private func nuclideHeader(_ nuclide: EditorFeature.ViewModel.NuclideRow) -> some View {
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

    // MARK: - Compartment row

    private func compartmentRow(
        _ comp: EditorFeature.ViewModel.CompartmentRow,
        proxy: ScrollViewProxy
    ) -> some View {
        let isSelected = selectedCompartmentId == comp.id
        return HStack(spacing: 10) {
            Circle()
                .fill(comp.tint.background(dark: colorScheme == .dark))
                .overlay(Circle().strokeBorder(comp.tint.border(dark: colorScheme == .dark),
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
            isSelected ? Color.accentColor.opacity(0.08) : Color.clear
        )
        .id(comp.id)
        .onTapGesture { onSelectCompartment(comp.id) }
    }

    // MARK: - Link row

    private func linkRow(_ link: EditorFeature.ViewModel.LinkRow) -> some View {
        let isSelected = selectedLinkIndex == link.id
        return HStack(spacing: 8) {
            Image(systemName: "arrow.forward")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text("K\(link.id + 1)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(link.fromTint.indicator(dark: colorScheme == .dark))
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
            isSelected ? Color.accentColor.opacity(0.08) : Color.clear
        )
        .id("link-\(link.id)")
        .onTapGesture { onSelectLink(link.id) }
    }

    // MARK: - Delete footer

    private var deleteFooter: some View {
        HStack {
            if let label = selectionFooterLabel {
                Label(label, systemImage: selectedCompartmentId != nil ? "square.fill" : "arrow.forward")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(role: .destructive, action: onDeleteSelected) {
                Label("Delete", systemImage: "trash")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Flag chip

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
        let m = self == 0 ? 0.0 : self / pow(10, Double(exp))
        return String(format: "%.2fe%+03d", m, exp)
    }
}
