import AppDomain
import SwiftUI
import Localization
import Vitral

// MARK: - EditorModelListPanel (pure)

struct EditorModelListPanel: View {
    let lingo: FieldLingo
    let nuclides: [EditorFeature.NuclideRow]
    let compartments: [EditorFeature.CompartmentRow]
    let links: [EditorFeature.LinkRow]
    let selectedCompartmentId: String?
    let selectedLinkIndex: Int?
    let selectionFooterLabel: LocalizedStringResource?
    var onSelectCompartment: (String?) -> Void
    var onSelectLink: (Int?) -> Void
    var onDeleteSelected: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L.Editor.compartmentsAndTransfers)
                    .font(TypeToken.sectionLabel)
                    .kerning(0.6)
                    .foregroundStyle(Color(.inkFaint))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Hairline()

            ScrollViewReader { proxy in
                GlassList {
                    if nuclides.count > 1 {
                        ForEach(nuclides) { nuclide in
                            let comps = compartments.filter { $0.nuclideId == nuclide.id }
                            GlassSection(LocalizedStringKey(nuclide.name), trailing: { halfLifeLabel(nuclide) }) {
                                ForEach(comps) { comp in
                                    compartmentRow(comp, proxy: proxy)
                                }
                            }
                        }
                    } else {
                        GlassSection(L.Common.compartments) {
                            ForEach(compartments) { comp in
                                compartmentRow(comp, proxy: proxy)
                            }
                        }
                    }

                    GlassSection(L.Common.transfers) {
                        ForEach(links) { link in
                            linkRow(link)
                        }
                    }
                }
                .onChange(of: selectedCompartmentId) { _, id in
                    if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                }
                .onChange(of: selectedLinkIndex) { _, idx in
                    if let idx { withAnimation { proxy.scrollTo("link-\(idx)", anchor: .center) } }
                }
            }

            // Delete footer
            if selectionFooterLabel != nil {
                Hairline()
                deleteFooter
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.2, dampingFraction: 0.9), value: selectionFooterLabel)
            }
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.9), value: selectionFooterLabel)
    }

    // MARK: - Nuclide header

    @ViewBuilder
    private func halfLifeLabel(_ nuclide: EditorFeature.NuclideRow) -> some View {
        if nuclide.halfLife > 0 {
            (Text(L.domain(lingo.halfLifeLabel)) + Text(verbatim: " \(nuclide.halfLife.formatted(.number.precision(.fractionLength(1)))) ") + Text(L.domain(lingo.timeUnit.label)))
        }
    }

    // MARK: - Compartment row

    private func compartmentRow(
        _ comp: EditorFeature.CompartmentRow,
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
                    .font(TypeToken.detail.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                if comp.follow || comp.dispose || comp.intake {
                    HStack(spacing: 4) {
                        if comp.follow  { flagChip(L.Editor.track) }
                        if comp.dispose { flagChip(L.domain(lingo.eliminationLabel)) }
                        if comp.intake  { flagChip(L.domain(lingo.intakeLabel)) }
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, Space.large)
        .frame(minHeight: Size.hitTarget)
        // The selection washes over the row's glass rather than replacing it.
        .background(isSelected ? Color(accent.base.opacity(0.14)) : Color.clear)
        .contentShape(Rectangle())
        .id(comp.id)
        .onTapGesture { onSelectCompartment(comp.id) }
    }

    // MARK: - Link row

    private func linkRow(_ link: EditorFeature.LinkRow) -> some View {
        let isSelected = selectedLinkIndex == link.id
        return HStack(spacing: 8) {
            Image(systemName: "arrow.forward")
                .font(TypeToken.sectionLabel.weight(.medium))
                .foregroundStyle(.inkMuted)
            Text("K\(link.id + 1)")
                .font(TypeToken.codeSmall.weight(.semibold))
                .foregroundStyle(link.fromTint.indicator(dark: colorScheme == .dark))
            Text("\(link.fromName) → \(link.toName)")
                .font(TypeToken.detail)
                .lineLimit(1)
            Spacer()
            Text(link.rate.scientificString)
                .font(TypeToken.codeSmall)
                .foregroundStyle(.inkFaint)
        }
        .padding(.horizontal, Space.large)
        .frame(minHeight: Size.hitTarget)
        // The selection washes over the row's glass rather than replacing it.
        .background(isSelected ? Color(accent.base.opacity(0.14)) : Color.clear)
        .contentShape(Rectangle())
        .id("link-\(link.id)")
        .onTapGesture { onSelectLink(link.id) }
    }

    // MARK: - Delete footer

    private var deleteFooter: some View {
        HStack {
            if let label = selectionFooterLabel {
                Label(label, systemImage: selectedCompartmentId != nil ? "square.fill" : "arrow.forward")
                    .font(.caption)
                    .foregroundStyle(.inkMuted)
                    .lineLimit(1)
            }
            Spacer()
            Button(role: .destructive, action: onDeleteSelected) {
                Label(L.Common.delete, systemImage: "trash")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Flag chip

    private func flagChip(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(TypeToken.sectionLabel.weight(.medium))
            .foregroundStyle(.inkMuted)
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
