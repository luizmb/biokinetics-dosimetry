import AppDomain
import SwiftRexArchitecture
import SwiftUI
import UniformTypeIdentifiers

// MARK: - HomeView

@BoundTo(HomeFeature.self)
public struct HomeView: View {
    @Environment(\.horizontalSizeClass) private var hSize

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                cardGrid
                    .padding(.horizontal, 16)
                    .padding(.bottom, 48)
            }
        }
        .background(Color.platformGroupedBackground.ignoresSafeArea())
        .navigationTitle("")
        .inlineNavigationTitle()
        .fileImporter(
            isPresented: Binding(
                get: { viewModel.filePicker.is(.loading) },
                // Only dispatch filePickerDismissed if still .loading — avoids a spurious
                // dismiss when importXML already moved us to .loaded(()).
                set: { presenting in
                    if !presenting && viewModel.filePicker.is(.loading) {
                        viewModel.dispatch(.filePickerDismissed)
                    }
                }
            ),
            allowedContentTypes: [UTType(filenameExtension: "xml") ?? .data]
        ) { result in
            if case .success(let url) = result,
               url.startAccessingSecurityScopedResource(),
               let data = try? Data(contentsOf: url) {
                url.stopAccessingSecurityScopedResource()
                viewModel.dispatch(.importXML(data))
            }
        }
        .alert(
            "Import Error",
            isPresented: Binding(
                get: { viewModel.cards.is(.failed) },
                set: { _ in }
            ),
            presenting: viewModel.cards.failed?.0.localizedDescription
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Biokinetics")
                    .font(.largeTitle.bold())
                Text("& Dosimetry")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                viewModel.dispatch(.openFilePicker)
            } label: {
                Label("Open XML", systemImage: "doc.badge.arrow.up")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                viewModel.dispatch(.newDocument)
            } label: {
                Label("New", systemImage: "plus")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    // MARK: - Card grid

    @ViewBuilder
    private var cardGrid: some View {
        let columns: [GridItem] = hSize == .compact
            ? [GridItem(.flexible())]
            : Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

        LazyVGrid(columns: columns, spacing: 16) {
            newModelTile
            ForEach(viewModel.cards.loadedOrPrevious ?? []) { card in
                ModelCard(card: card) {
                    viewModel.dispatch(.editDocument(card.document))
                } onCalculate: {
                    viewModel.dispatch(.calculateDocument(card.document))
                } onDelete: {
                    viewModel.dispatch(.deleteDocument(card.id))
                }
            }
        }
    }

    private var newModelTile: some View {
        Button {
            viewModel.dispatch(.newDocument)
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        .foregroundStyle(.tertiary)
                        .frame(width: 52, height: 52)
                    Image(systemName: "plus")
                        .font(.title2.weight(.light))
                        .foregroundStyle(.secondary)
                }
                Text("New blank model")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 164)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundStyle(.quaternary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ModelCard

private struct ModelCard: View {
    let card: HomeFeature.ViewModel.DocumentCard
    var onEdit: () -> Void
    var onCalculate: () -> Void
    var onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var dark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tintSwatchRow
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider().opacity(0.4)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                    .lineLimit(1)
                if !card.description.isEmpty {
                    Text(card.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    Label("\(card.compartmentCount)", systemImage: "square.stack.3d.up")
                    Label("\(card.connectionCount)", systemImage: "arrow.triangle.branch")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().opacity(0.4)

            HStack(spacing: 0) {
                actionBtn("Edit", icon: "pencil", action: onEdit)
                Divider().frame(height: 36)
                actionBtn("Calculate", icon: "waveform.path.ecg", action: onCalculate)
                Divider().frame(height: 36)
                actionBtn("", icon: "trash", role: .destructive, width: 44, action: onDelete)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(dark ? 0.28 : 0.07), radius: 8, y: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var tintSwatchRow: some View {
        HStack {
            HStack(spacing: -6) {
                ForEach(Array(card.tints.prefix(5).enumerated()), id: \.0) { idx, tint in
                    Circle()
                        .fill(tint.fillColor(dark: dark))
                        .overlay(Circle().strokeBorder(tint.strokeColor(dark: dark), lineWidth: 0.5))
                        .frame(width: 22, height: 22)
                        .zIndex(Double(5 - idx))
                }
            }
            Spacer()
            if card.halfLife > 0 {
                Text("T½ \(card.halfLife.formatted(.number.precision(.fractionLength(1)))) d")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    @ViewBuilder
    private func actionBtn(
        _ label: String,
        icon: String,
        role: ButtonRole? = nil,
        width: CGFloat? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12, weight: .medium))
                if !label.isEmpty { Text(label).font(.system(size: 12, weight: .medium)) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? .red : .accentColor)
        .frame(width: width)
    }
}
