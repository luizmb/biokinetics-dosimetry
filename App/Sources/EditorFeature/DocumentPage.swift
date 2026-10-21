import AppDomain
import Domain
import SwiftUI
import Localization
import Vitral

// MARK: - EditorDocumentPage (pure)

/// The left panel's first page: the document's own settings. Its name and description, how it is
/// drawn (the rates on the arrows, the backdrop), its field, its variants and its substances, and
/// what is wrong with it. Always here, whatever is selected.
struct EditorDocumentPage: View {
    @Binding var documentName: String
    @Binding var documentDescription: String
    @Binding var field: ModelField
    @Binding var backdrop: EditorBackdrop?
    /// The rates (K) written on the arrows.
    var showKValues: Binding<Bool>
    let lingo: FieldLingo
    let units: WorkingUnits
    var nuclideBindings: [NuclideEditBinding]
    let validationIssues: [CompartmentalModel.ValidationIssue]
    /// Each issue's text, in step with `validationIssues`, written where the view state is made.
    let validationIssueTexts: [LocalizedStringResource]

    var onAddNuclide:           () -> Void
    var onDeleteNuclide:        (String) -> Void
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

    /// The screen's appearance, from its parent's view state.
    let colorScheme: ColorScheme
    /// A number field was left: what it shows is the value again.
    var onEndNumberEditing: () -> Void
    private var dark: Bool { colorScheme == .dark }

    var body: some View {
        ScrollView {
            settings
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The one switch for the rates on the arrows: how the model is drawn, so it lives with
            // the document rather than over the canvas.
            Panel(cornerRadius: 16, padding: 0) {
                ToggleSwitch(L.Editor.showRatesOnArrows, isOn: showKValues)
                    .padding(.horizontal, 15)
            }
            .padding(.bottom, 18)

            SectionLabel(L.Common.name)
            FieldText(L.Common.modelName, text: $documentName)
            .padding(.bottom, 14)

            SectionLabel(L.Editor.description)
            FieldText(L.Editor.optionalDescription, text: $documentDescription, axis: .vertical)
                .lineLimit(3...5)
                .padding(.bottom, 18)

            if !validationIssues.isEmpty {
                SectionLabel(L.Editor.issues)
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

            SectionLabel(L.Editor.variants)
            Panel(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    variantRow(key: nil, label: Text(L.Editor.baseModel))
                    ForEach(variants, id: \.self) { key in
                        Hairline()
                        variantRow(key: key, label: Text(verbatim: key))
                    }
                }
            }
            .padding(.bottom, 8)

            Button {
                let name = String(localized: L.Resource.Editor.variantNumber(variants.count + 1))
                onAddVariant(name)
            } label: {
                Label(L.Editor.addVariant, systemImage: "plus.circle")
                    .font(TypeToken.bodyStrong)
                    .foregroundStyle(Color(.accent, scheme: colorScheme))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 18)

            SectionLabel(L.Common.field)
            Panel(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(ModelField.allCases.enumerated()), id: \.1) { idx, f in
                        if idx > 0 { Hairline() }
                        HStack {
                            Text(L.domain(f.lingo.fieldName)).font(TypeToken.body)
                            Spacer()
                            if field == f {
                                Image(systemName: "checkmark").font(TypeToken.detail.weight(.semibold))
                                    .foregroundStyle(Color(.accent, scheme: colorScheme))
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .contentShape(Rectangle())
                        .onTapGesture { field = f }
                    }
                }
            }
            .padding(.bottom, 18)

            SectionLabel(L.Editor.backdrop)
            BackdropPicker(selection: $backdrop, fieldDefault: field.backdrop)
                .padding(.bottom, 18)

            SectionLabel(L.domain(lingo.substancesLabel))
            Panel(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(nuclideBindings.enumerated()), id: \.1.id) { idx, nb in
                        if idx > 0 { Hairline() }
                        nuclideEditorRow(nb)
                    }
                    if nuclideBindings.isEmpty {
                        Text(L.Editor.noSubstances(L.domainString(lingo.substancesLabel)))
                            .font(.caption).foregroundStyle(.inkMuted)
                            .padding(12).frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.bottom, 8)

            Button { onAddNuclide() } label: {
                Label(L.Editor.add(L.domainString(lingo.substanceName)), systemImage: "plus.circle")
                    .font(TypeToken.bodyStrong)
                    .foregroundStyle(Color(.accent, scheme: colorScheme))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    @ViewBuilder
    private func variantRow(key: String?, label: Text) -> some View {
        let isEditing  = editingVariant == key
        let isRenaming = key != nil && renamingVariant == key

        if isRenaming {
            HStack(spacing: 8) {
                FieldText(L.Editor.variantName, text: $variantRenameDraft)
                    .submitLabel(.done)
                    .onSubmit { onCommitVariantRename() }
                Button(L.Common.done) { onCommitVariantRename() }
                    .font(TypeToken.detail.weight(.semibold))
                    .foregroundStyle(Color(.accent, scheme: colorScheme))
                    .buttonStyle(PlainButtonStyle())
                Button { onCancelVariantRename() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.inkMuted)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
        } else {
            HStack {
                label.font(TypeToken.body)
                Spacer()
                if isEditing {
                    Image(systemName: "pencil.circle.fill")
                        .font(TypeToken.detail.weight(.semibold))
                        .foregroundStyle(Color(.accent, scheme: colorScheme))
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
            .background(isEditing ? Color(.accent, scheme: colorScheme).opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { onSelectEditingVariant(key) }
        }
    }

    @ViewBuilder
    private func nuclideEditorRow(_ nb: NuclideEditBinding) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                FieldText(L.Common.name, text: nb.name)
                if nb.canDelete {
                    Button(role: .destructive) { onDeleteNuclide(nb.id) } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.danger)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            if nb.halfLife.wrappedValue == 0 && !lingo.isHalfLifeRequired {
                HStack(spacing: 6) {
                    Text(L.domain(lingo.halfLifeLabel)).font(TypeToken.sectionLabel.weight(.medium)).foregroundStyle(.inkMuted)
                    Text(L.Common.none)
                        .font(TypeToken.codeSmall)
                        .foregroundStyle(.inkFaint)
                        .onTapGesture { nb.halfLifeText.wrappedValue = "1" }
                }
            } else {
                HStack(spacing: Space.small) {
                    Text(L.domain(lingo.halfLifeLabel)).font(TypeToken.sectionLabel.weight(.medium)).foregroundStyle(.inkMuted)
                    FieldText(
                        "0",
                        text: nb.halfLifeText,
                        suffix: Text(L.domain(units.time.symbol)),
                        keyboard: .decimal,
                        onEndEditing: onEndNumberEditing
                    )
                    .accessibilityLabel(Text(L.domain(lingo.halfLifeLabel)))
                }
            }
            if nb.compartmentCount > 0 {
                Text(L.Editor.compartmentCount(nb.compartmentCount))
                    .font(TypeToken.sectionLabel.weight(.regular)).foregroundStyle(.inkFaint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func issueRow(_ issue: CompartmentalModel.ValidationIssue) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: issue.systemImageName)
                .font(TypeToken.detail)
                .foregroundStyle(issueTint(issue.severity))
                .frame(width: 20)
            Text(validationIssues.firstIndex(of: issue).map { validationIssueTexts[$0] } ?? "")
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
        case .info:    Color(.inkMuted, scheme: colorScheme)
        }
    }
}
