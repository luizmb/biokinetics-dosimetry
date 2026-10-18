import AppDomain
import SwiftUI
import Localization
import Vitral

struct NewDocumentSheet: View {
    @Binding var field: ModelField
    @Binding var name: String
    var onConfirm: () -> Void
    var onCancel: () -> Void
    /// Deleted sample models that can come back; the button is hidden at 0.
    let restorableSampleCount: Int
    var onRestoreSampleModels: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                Backdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionLabel(L.Common.field)
                        Panel(cornerRadius: 16, padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(Array(ModelField.allCases.enumerated()), id: \.1) { idx, f in
                                    if idx > 0 { Hairline() }
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(L.domain(f.lingo.fieldName))
                                                .font(TypeToken.body)
                                            (Text(L.domain(f.lingo.substanceName)) + Text(verbatim: " · ") + Text(L.domain(f.lingo.intakeLabel)) + Text(verbatim: " · ") + Text(L.domain(f.lingo.eliminationLabel)))
                                                .font(TypeToken.sectionLabel.weight(.regular))
                                                .foregroundStyle(Color(.inkFaint))
                                        }
                                        Spacer()
                                        if field == f {
                                            Image(systemName: "checkmark")
                                                .font(TypeToken.detail.weight(.semibold))
                                                .foregroundStyle(Color(.accent))
                                        }
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 11)
                                    .contentShape(Rectangle())
                                    .onTapGesture { field = f }
                                }
                            }
                        }
                        .padding(.bottom, 24)

                        SectionLabel(L.Common.name)
                        FieldText(L.Common.modelName, text: $name)
                        .padding(.bottom, 8)

                        Text(L.Home.renameHint)
                            .font(.caption)
                            .foregroundStyle(Color(.inkFaint))
                            .padding(.horizontal, 4)

                        if restorableSampleCount > 0 {
                            SectionLabel(L.Home.sampleModels)
                                .padding(.top, 28)
                            ButtonSecondary(
                                L.Home.restoreSamples(restorableSampleCount),
                                icon: Image(systemName: "arrow.counterclockwise"),
                                size: .medium,
                                fillsWidth: true,
                                action: onRestoreSampleModels
                            )
                            Text(L.Home.restoreSamplesHint)
                                .font(.caption)
                                .foregroundStyle(Color(.inkFaint))
                                .padding(.horizontal, 4)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(L.Home.newModel)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.Common.cancel, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.Common.create, action: onConfirm)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.fraction(0.80)])
        .presentationDragIndicator(.visible)
    }
}
