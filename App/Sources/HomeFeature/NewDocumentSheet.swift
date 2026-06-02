import AppDomain
import SwiftUI
import UIComponents

struct NewDocumentSheet: View {
    @Binding var field: ModelField
    @Binding var name: String
    var onConfirm: () -> Void
    var onCancel: () -> Void

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
