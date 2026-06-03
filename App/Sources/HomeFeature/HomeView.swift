import AppDomain
import SwiftRexArchitecture
import SwiftUI
import UIComponents
import UniformTypeIdentifiers

// MARK: - HomeView (container — thin SwiftRex wrapper)

@BoundTo(HomeFeature.self)
public struct HomeView: View {
    public var body: some View {
        HomeContent(
            cards: viewModel.cards.loadedOrPrevious ?? [],
            isLoading: viewModel.cards.is(.loading),
            importErrorMessage: viewModel.importErrorMessage,
            isFilePickerPresented: Binding(
                get: { viewModel.filePicker.is(.loading) },
                set: { presenting in
                    if !presenting && viewModel.filePicker.is(.loading) {
                        viewModel.dispatch(.filePickerDismissed)
                    }
                }
            ),
            isCreationSheetPresented: Binding(
                get: { viewModel.isCreationSheetOpen },
                set: { if !$0 { viewModel.dispatch(.dismissCreationSheet) } }
            ),
            draftField: Binding(
                get: { viewModel.draftField },
                set: { viewModel.dispatch(.setDraftField($0)) }
            ),
            draftName: Binding(
                get: { viewModel.draftName },
                set: { viewModel.dispatch(.setDraftName($0)) }
            ),
            onOpenFilePicker:   { viewModel.dispatch(.openFilePicker) },
            isCreditsSheetPresented: Binding(
                get: { viewModel.isCreditsSheetOpen },
                set: { if !$0 { viewModel.dispatch(.closeCredits) } }
            ),
            onOpenCredits: { viewModel.dispatch(.openCredits) },
            onOpenCreationSheet: { viewModel.dispatch(.openCreationSheet) },
            onConfirmNewDocument: { viewModel.dispatch(.newDocument(field: viewModel.draftField, name: viewModel.draftName)) },
            onCancelNewDocument: { viewModel.dispatch(.dismissCreationSheet) },
            onEdit:              { viewModel.dispatch(.editDocument($0)) },
            onCalculate:         { viewModel.dispatch(.calculateDocument($0)) },
            onDuplicate:         { viewModel.dispatch(.duplicateDocument($0)) },
            onDelete:            { viewModel.dispatch(.deleteDocument($0)) },
            onImportFile: { ext, data in
                switch ext.lowercased() {
                case "json": viewModel.dispatch(.importJSON(data))
                case "csv":  viewModel.dispatch(.importCSV(data))
                default:     viewModel.dispatch(.importXML(data))
                }
            }
        )
    }
}

// MARK: - HomeContent (pure view — no SwiftRex dependency)

struct HomeContent: View {
    // MARK: Props
    let cards: [HomeFeature.ViewModel.DocumentCard]
    let isLoading: Bool
    let importErrorMessage: String?
    @Binding var isFilePickerPresented: Bool
    @Binding var isCreationSheetPresented: Bool
    @Binding var draftField: ModelField
    @Binding var draftName: String
    var onOpenFilePicker:     () -> Void
    @Binding var isCreditsSheetPresented: Bool
    var onOpenCredits:        () -> Void
    var onOpenCreationSheet:  () -> Void
    var onConfirmNewDocument: () -> Void
    var onCancelNewDocument: () -> Void
    var onEdit:              (ModelDocument) -> Void
    var onCalculate:         (ModelDocument) -> Void
    var onDuplicate:         (ModelDocument.ID) -> Void
    var onDelete:            (ModelDocument.ID) -> Void
    var onImportFile:        (String, Data) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSize
    private var isCompact: Bool { hSize == .compact }

    var body: some View {
        ZStack {
            GlassAppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if let msg = importErrorMessage {
                        GBanner(tone: .danger,
                                systemImage: "exclamationmark.triangle",
                                message: msg)
                            .padding(.horizontal, isCompact ? 16 : 36)
                            .padding(.bottom, 8)
                    }
                    contentArea
                }
            }
        }
        .sheet(isPresented: $isCreationSheetPresented) {
            NewDocumentSheet(
                field: $draftField,
                name: $draftName,
                onConfirm: onConfirmNewDocument,
                onCancel: onCancelNewDocument
            )
        }
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: [
                UTType(filenameExtension: "xml")  ?? .data,
                UTType(filenameExtension: "json") ?? .json,
                UTType(filenameExtension: "csv")  ?? .commaSeparatedText,
            ]
        ) { result in
            guard case .success(let url) = result,
                  url.startAccessingSecurityScopedResource(),
                  let data = try? Data(contentsOf: url) else { return }
            let ext = url.pathExtension
            url.stopAccessingSecurityScopedResource()
            onImportFile(ext, data)
        }
        .sheet(isPresented: $isCreditsSheetPresented) {
            CreditsSheet(onDismiss: { isCreditsSheetPresented = false })
        }
        .inlineNavigationTitle()
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        let vPad: CGFloat = isCompact ? 6 : 28
        let hPad: CGFloat = isCompact ? 16 : 36

        VStack(alignment: .leading, spacing: 0) {
            // Action pills row
            HStack(spacing: 8) {
                Button(action: onOpenCredits) {
                    Image(systemName: "info.circle")
                        .font(.system(size: isCompact ? 20 : 22))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                Spacer()
                GPill(intensity: 0.85, action: onOpenFilePicker) {
                    Label("Import", systemImage: "doc.badge.arrow.up")
                        .font(.system(size: isCompact ? 14 : 15, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, isCompact ? 13 : 16)
                        .frame(height: isCompact ? 38 : 42)
                }
                GButton("New", icon: Image(systemName: "plus"),
                        size: isCompact ? .sm : .md, action: onOpenCreationSheet)
            }
            .padding(.horizontal, hPad)
            .padding(.top, isCompact ? 4 : 8)

            // Large title
            VStack(alignment: .leading, spacing: 2) {
                Text("Biokinetics")
                    .font(.system(size: isCompact ? 40 : 44, weight: .heavy))
                    .tracking(-1.4)
                    .foregroundStyle(.primary)
                Text("& Dosimetry")
                    .font(.system(size: isCompact ? 20 : 22, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, hPad)
            .padding(.top, 4)
            .padding(.bottom, vPad)
        }
    }

    // MARK: - Content area (grid vs list)

    @ViewBuilder
    private var contentArea: some View {
        let hPad: CGFloat = isCompact ? 16 : 36

        if isCompact {
            compactList.padding(.horizontal, hPad).padding(.bottom, 48)
        } else {
            regularGrid.padding(.horizontal, hPad).padding(.bottom, 48)
        }
    }

    // MARK: - Compact (iPhone-style flat list)

    private var compactList: some View {
        VStack(spacing: 14) {
            newModelBox(big: cards.isEmpty)
            if isLoading {
                loadingSpinner
            } else if !cards.isEmpty {
                GCard(cornerRadius: 22, intensity: 0.5,
                      tint: colorScheme == .dark
                            ? Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.34)
                            : Color.white.opacity(0.42)) {
                    VStack(spacing: 0) {
                        ForEach(Array(cards.enumerated()), id: \.1.id) { idx, card in
                            if idx > 0 { GlassDivider() }
                            HomeListRow(
                                card: card,
                                onEdit:      { onEdit(card.document) },
                                onCalculate: { onCalculate(card.document) },
                                onDuplicate: { onDuplicate(card.id) },
                                onDelete:    { onDelete(card.id) }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Regular (iPad 3-column grid)

    private var regularGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3),
            spacing: 20
        ) {
            newModelBox(big: false)
            if isLoading {
                loadingSpinnerCard
            } else {
                ForEach(cards) { card in
                    HomeModelCard(
                        card: card,
                        onEdit:      { onEdit(card.document) },
                        onCalculate: { onCalculate(card.document) },
                        onDuplicate: { onDuplicate(card.id) },
                        onDelete:    { onDelete(card.id) }
                    )
                }
            }
        }
    }

    // MARK: - New model box

    private func newModelBox(big: Bool) -> some View {
        Button(action: onOpenCreationSheet) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .foregroundStyle(.tertiary)
                        .frame(width: 60, height: 60)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.secondary)
                }
                Text("New blank model")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: big ? 220 : 132)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [6]),
                        antialiased: true
                    )
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.22)
                            : Color.black.opacity(0.20)
                    )
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        colorScheme == .dark
                            ? Color.white.opacity(0.03)
                            : Color.white.opacity(0.28)
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Loading

    private var loadingSpinner: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading documents…")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var loadingSpinnerCard: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading…")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 164)
        .glassBackground(cornerRadius: 20)
    }
}

// MARK: - HomeListRow (compact flat-list card)

private struct HomeListRow: View {
    let card: HomeFeature.ViewModel.DocumentCard
    var onEdit:      () -> Void
    var onCalculate: () -> Void
    var onDuplicate: () -> Void
    var onDelete:    () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.glassTokens) private var g

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                SwatchCluster(tints: card.tints)
                Spacer()
                if card.halfLife > 0 {
                    GPill(intensity: 0.7) {
                        Text("\(card.field.lingo.halfLifeLabel) \(card.halfLife.formatted(.number.precision(.fractionLength(1)))) \(card.field.lingo.timeUnit.label)")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(g.muted)
                            .padding(.horizontal, 11)
                            .frame(height: 26)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.3)
                if !card.description.isEmpty {
                    Text(card.description)
                        .font(.system(size: 14.5))
                        .foregroundStyle(g.muted)
                }
                HStack(spacing: 16) {
                    countStat(systemImage: "square.stack.3d.up", n: card.compartmentCount)
                    countStat(systemImage: "arrow.triangle.branch", n: card.connectionCount)
                }
                .padding(.top, 7)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            GlassDivider()

            HStack(spacing: 0) {
                actionBtn("Edit",      systemImage: "pencil",           accent: true,  action: onEdit)
                GlassVDivider().frame(height: 26)
                actionBtn("Calculate", systemImage: "waveform.path.ecg", accent: true,  action: onCalculate)
                GlassVDivider().frame(height: 26)
                actionBtn("",          systemImage: "doc.on.doc",        accent: false, action: onDuplicate)
                    .frame(width: 52)
                GlassVDivider().frame(height: 26)
                actionBtn("",          systemImage: "trash",             accent: false, danger: true, action: onDelete)
                    .frame(width: 52)
            }
        }
    }

    private func actionBtn(
        _ label: String,
        systemImage: String,
        accent: Bool,
        danger: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                if !label.isEmpty { Text(label).font(.system(size: 15.5, weight: .semibold)) }
            }
            .foregroundStyle(danger
                             ? (colorScheme == .dark ? Color(hex: 0xFF7A6B) : Color(hex: 0xE0402E))
                             : g.accent)
            .frame(maxWidth: label.isEmpty ? nil : .infinity)
            .frame(height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func countStat(systemImage: String, n: Int) -> some View {
        Label("\(n)", systemImage: systemImage)
            .font(.system(size: 13.5))
            .foregroundStyle(g.faint)
    }
}

// MARK: - HomeModelCard (iPad grid card)

private struct HomeModelCard: View {
    let card: HomeFeature.ViewModel.DocumentCard
    var onEdit:      () -> Void
    var onCalculate: () -> Void
    var onDuplicate: () -> Void
    var onDelete:    () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.glassTokens) private var g

    var body: some View {
        GCard(cornerRadius: 20, intensity: 0.55,
              tint: colorScheme == .dark
                    ? Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.40)
                    : Color.white.opacity(0.50)) {
            VStack(alignment: .leading, spacing: 0) {
                // Swatches + half-life
                HStack {
                    SwatchCluster(tints: card.tints)
                    Spacer()
                    if card.halfLife > 0 {
                        GPill(intensity: 0.7) {
                            Text("\(card.field.lingo.halfLifeLabel) \(card.halfLife.formatted(.number.precision(.fractionLength(1)))) \(card.field.lingo.timeUnit.label)")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(g.muted)
                                .padding(.horizontal, 11)
                                .frame(height: 26)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // Name + description + counts
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name)
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.3)
                    if !card.description.isEmpty {
                        Text(card.description)
                            .font(.system(size: 14.5))
                            .foregroundStyle(g.muted)
                    }
                    HStack(spacing: 16) {
                        Label("\(card.compartmentCount)", systemImage: "square.stack.3d.up")
                        Label("\(card.connectionCount)", systemImage: "arrow.triangle.branch")
                    }
                    .font(.system(size: 13.5))
                    .foregroundStyle(g.faint)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                GlassDivider()

                // Action row
                HStack(spacing: 0) {
                    gridActionBtn("Edit",      systemImage: "pencil",            action: onEdit)
                    GlassVDivider().frame(height: 26)
                    gridActionBtn("Calculate", systemImage: "waveform.path.ecg", action: onCalculate)
                    GlassVDivider().frame(height: 26)
                    gridActionBtn("",          systemImage: "doc.on.doc",         action: onDuplicate)
                        .frame(width: 48)
                    GlassVDivider().frame(height: 26)
                    gridActionBtn("",          systemImage: "trash", danger: true, action: onDelete)
                        .frame(width: 48)
                }
            }
        }
    }

    private func gridActionBtn(
        _ label: String,
        systemImage: String,
        danger: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage).font(.system(size: 13, weight: .medium))
                if !label.isEmpty { Text(label).font(.system(size: 14.5, weight: .semibold)) }
            }
            .foregroundStyle(danger
                             ? (colorScheme == .dark ? Color(hex: 0xFF7A6B) : Color(hex: 0xE0402E))
                             : g.accent)
            .frame(maxWidth: label.isEmpty ? nil : .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
