import AppDomain
import SwiftUI
import Localization
import Vitral

// MARK: - EditorModelListPanel (pure)

/// The left panel's second page: what the model is made of. Tapping a row picks it (and shows
/// it on the canvas); the picked row offers Edit, which opens the inspector on it, and Delete.
/// New compartments and transfers are added here too.
struct EditorModelListPanel: View {
    let lingo: FieldLingo
    let units: WorkingUnits
    let nuclides: [EditorFeature.NuclideRow]
    let compartments: [EditorFeature.CompartmentRow]
    let links: [EditorFeature.LinkRow]
    let selectedCompartmentId: String?
    let selectedLinkIndex: Int?
    var onSelectCompartment: (String?) -> Void
    var onSelectLink: (Int?) -> Void
    var onEditCompartment: (String) -> Void
    var onEditLink: (Int) -> Void
    var onDeleteCompartment: (String) -> Void
    var onDeleteLink: (Int) -> Void
    var onAddCompartment: () -> Void
    var onAddTransfer: () -> Void

    /// The screen's appearance, from its parent's view state.
    let colorScheme: ColorScheme
    @Environment(\.accent) private var accent

    var body: some View {
        ScrollViewReader { proxy in
            GlassList {
                if nuclides.count > 1 {
                    ForEach(nuclides) { nuclide in
                        let comps = compartments.filter { $0.nuclideId == nuclide.id }
                        GlassSection(LocalizedStringKey(nuclide.name), trailing: { halfLifeLabel(nuclide) }) {
                            ForEach(comps) { comp in
                                compartmentRow(comp)
                            }
                        }
                    }
                    GlassSection {
                        addRow(L.Editor.addCompartment, action: onAddCompartment)
                    }
                } else {
                    GlassSection(L.Common.compartments) {
                        ForEach(compartments) { comp in
                            compartmentRow(comp)
                        }
                        addRow(L.Editor.addCompartment, action: onAddCompartment)
                    }
                }

                GlassSection(L.Common.transfers) {
                    ForEach(links) { link in
                        linkRow(link)
                    }
                    addRow(L.Editor.addTransfer, action: onAddTransfer)
                }
            }
            .onChange(of: selectedCompartmentId) { _, id in
                if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
            }
            .onChange(of: selectedLinkIndex) { _, idx in
                if let idx { withAnimation { proxy.scrollTo("link-\(idx)", anchor: .center) } }
            }
        }
    }

    /// A row that adds one more of something.
    private func addRow(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus.circle")
                .font(TypeToken.bodyStrong)
                .foregroundStyle(Color(.accent, scheme: colorScheme))
                .frame(maxWidth: .infinity, minHeight: Size.hitTarget, alignment: .leading)
                .padding(.horizontal, Space.large)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Edit and Delete, on the picked row only.
    private func rowActions(edit: @escaping () -> Void, delete: @escaping () -> Void) -> some View {
        HStack(spacing: Space.medium) {
            Button(action: edit) {
                Image(systemName: "pencil")
                    .font(TypeToken.bodyStrong)
                    .foregroundStyle(Color(.accent, scheme: colorScheme))
                    .frame(width: Size.hitTarget, height: Size.hitTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text(L.Common.edit))
            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
                    .font(TypeToken.bodyStrong)
                    .foregroundStyle(.danger)
                    .frame(width: Size.hitTarget, height: Size.hitTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text(L.Common.delete))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Nuclide header

    @ViewBuilder
    private func halfLifeLabel(_ nuclide: EditorFeature.NuclideRow) -> some View {
        if nuclide.halfLife > 0 {
            (Text(L.domain(lingo.halfLifeLabel)) + Text(verbatim: " \(nuclide.halfLifeShortText) ") + Text(L.domain(units.time.symbol)))
        }
    }

    // MARK: - Compartment row

    private func compartmentRow(_ comp: EditorFeature.CompartmentRow) -> some View {
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
            if isSelected {
                rowActions(edit: { onEditCompartment(comp.id) }, delete: { onDeleteCompartment(comp.id) })
            }
        }
        .padding(.leading, Space.large)
        .padding(.trailing, isSelected ? Space.small : Space.large)
        .frame(minHeight: Size.hitTarget)
        // The selection washes over the row's glass rather than replacing it.
        .background(isSelected ? Color(accent.base.opacity(0.14), scheme: colorScheme) : Color.clear)
        .contentShape(Rectangle())
        .id(comp.id)
        .onTapGesture { onSelectCompartment(isSelected ? nil : comp.id) }
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
            if isSelected {
                rowActions(edit: { onEditLink(link.id) }, delete: { onDeleteLink(link.id) })
            } else {
                Text(verbatim: link.rateText)
                    .font(TypeToken.codeSmall)
                    .foregroundStyle(.inkFaint)
            }
        }
        .padding(.leading, Space.large)
        .padding(.trailing, isSelected ? Space.small : Space.large)
        .frame(minHeight: Size.hitTarget)
        // The selection washes over the row's glass rather than replacing it.
        .background(isSelected ? Color(accent.base.opacity(0.14), scheme: colorScheme) : Color.clear)
        .contentShape(Rectangle())
        .id("link-\(link.id)")
        .onTapGesture { onSelectLink(isSelected ? nil : link.id) }
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

