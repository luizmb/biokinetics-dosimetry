import AppDomain
import SwiftUI
import Vitral
import VitralTokens

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
                        SectionLabel("Field")
                        Panel(cornerRadius: 16, padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(Array(ModelField.allCases.enumerated()), id: \.1) { idx, f in
                                    if idx > 0 { Hairline() }
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(f.lingo.fieldName)
                                                .font(.system(size: 15))
                                            Text("\(f.lingo.substanceName) · \(f.lingo.intakeLabel) · \(f.lingo.eliminationLabel)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color(.inkFaint))
                                        }
                                        Spacer()
                                        if field == f {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .semibold))
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

                        SectionLabel("Name")
                        Panel(cornerRadius: 12, padding: 0) {
                            TextField("Model name", text: $name)
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                        }
                        .padding(.bottom, 8)

                        Text("You can rename the model and change its field at any time from the editor.")
                            .font(.caption)
                            .foregroundStyle(Color(.inkFaint))
                            .padding(.horizontal, 4)

                        if restorableSampleCount > 0 {
                            SectionLabel("Sample models")
                                .padding(.top, 28)
                            ButtonSecondary(
                                restorableSampleCount == 1 ? "Restore 1 sample model" : "Restore \(restorableSampleCount) sample models",
                                icon: Image(systemName: "arrow.counterclockwise"),
                                size: .medium,
                                fillsWidth: true,
                                action: onRestoreSampleModels
                            )
                            Text("Brings back the sample models you deleted. Samples you edited stay as they are.")
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
            .navigationTitle("New Model")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: onConfirm)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.fraction(0.80)])
        .presentationDragIndicator(.visible)
    }
}
