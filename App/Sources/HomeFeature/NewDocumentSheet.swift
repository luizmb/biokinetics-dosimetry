import AppDomain
import SwiftUI
import UIComponents

struct NewDocumentSheet: View {
    @Binding var field: ModelField
    @Binding var name: String
    var onConfirm: () -> Void
    var onCancel: () -> Void
    /// Deleted sample models that can come back; the button is hidden at 0.
    let restorableSampleCount: Int
    var onRestoreSampleModels: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.glassTokens) private var g

    var body: some View {
        NavigationStack {
            ZStack {
                GlassAppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        GLabel("Field")
                        GCard(cornerRadius: 16, intensity: 0.5) {
                            VStack(spacing: 0) {
                                ForEach(Array(ModelField.allCases.enumerated()), id: \.1) { idx, f in
                                    if idx > 0 { GlassDivider() }
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(f.lingo.fieldName)
                                                .font(.system(size: 15))
                                            Text("\(f.lingo.substanceName) · \(f.lingo.intakeLabel) · \(f.lingo.eliminationLabel)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(g.faint)
                                        }
                                        Spacer()
                                        if field == f {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(g.accent)
                                        }
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 11)
                                    .contentShape(Rectangle())
                                    .onTapGesture { field = f }
                                }
                            }
                        }
                        .padding(.bottom, 24)

                        GLabel("Name")
                        GCard(cornerRadius: 12, intensity: 0.5) {
                            TextField("Model name", text: $name)
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                        }
                        .padding(.bottom, 8)

                        Text("You can rename the model and change its field at any time from the editor.")
                            .font(.caption)
                            .foregroundStyle(g.faint)
                            .padding(.horizontal, 4)

                        if restorableSampleCount > 0 {
                            GLabel("Sample models")
                                .padding(.top, 28)
                            GButton(
                                restorableSampleCount == 1 ? "Restore 1 sample model" : "Restore \(restorableSampleCount) sample models",
                                icon: Image(systemName: "arrow.counterclockwise"),
                                tone: .neutral,
                                size: .md,
                                fullWidth: true,
                                action: onRestoreSampleModels
                            )
                            Text("Brings back the sample models you deleted. Samples you edited stay as they are.")
                                .font(.caption)
                                .foregroundStyle(g.faint)
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
