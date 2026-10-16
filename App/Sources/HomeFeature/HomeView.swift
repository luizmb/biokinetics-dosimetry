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
            cards: viewStore.state.cards.value.loadedOrPrevious ?? [],
            isLoading: viewStore.state.cards.value.is(.loading),
            importErrorMessage: viewStore.state.importErrorMessage,
            isFilePickerPresented: viewStore.binding(.state(\.isFilePickerOpen).action(review: { (open: Bool) in open ? .openFilePicker : .filePickerDismissed })),
            isCreationSheetPresented: viewStore.binding(.state(\.isCreationSheetOpen).action(review: { (open: Bool) in open ? .openCreationSheet : .dismissCreationSheet })),
            draftField: viewStore.binding(.state(\.draftField).action(\.setDraftField)),
            draftName:  viewStore.binding(.state(\.draftName).action(\.setDraftName)),
            onOpenFilePicker:   { viewStore.dispatch(.openFilePicker) },
            isCreditsSheetPresented: viewStore.binding(.state(\.isCreditsSheetOpen).action(review: { (open: Bool) in open ? .openCredits : .closeCredits })),
            onOpenCredits: { viewStore.dispatch(.openCredits) },
            onOpenCreationSheet: { viewStore.dispatch(.openCreationSheet) },
            onConfirmNewDocument: { viewStore.dispatch(.newDocument(field: viewStore.state.draftField.value, name: viewStore.state.draftName)) },
            onCancelNewDocument: { viewStore.dispatch(.dismissCreationSheet) },
            restorableSampleCount: viewStore.state.restorableSampleCount,
            onRestoreSampleModels: { viewStore.dispatch(.restoreSampleModels) },
            onEdit:              { viewStore.dispatch(.editDocument($0)) },
            onCalculate:         { viewStore.dispatch(.calculateDocument($0)) },
            onDuplicate:         { viewStore.dispatch(.duplicateDocument($0)) },
            onDelete:            { viewStore.dispatch(.deleteDocument($0)) },
            onImportFile: { ext, data in
                switch ext.lowercased() {
                case "json": viewStore.dispatch(.importJSON(data))
                case "csv":  viewStore.dispatch(.importCSV(data))
                default:     viewStore.dispatch(.importXML(data))
                }
            }
        )
    }
}

// MARK: - HomeContent (pure view — no SwiftRex dependency)

struct HomeContent: View {
    // MARK: Props
    let cards: [HomeFeature.DocumentCard]
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
    let restorableSampleCount: Int
    var onRestoreSampleModels: () -> Void
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
            // The editor's graph paper, fixed while the cards scroll over it: the glass has lines
            // to bend, and Home and the editor share a look.
            GlassBackdrop()
                .ignoresSafeArea()
            GeometryReader { geo in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        if let msg = importErrorMessage {
                            GBanner(tone: .danger,
                                    systemImage: "exclamationmark.triangle",
                                    message: msg)
                                .padding(.horizontal, isCompact ? 16 : 36)
                                .padding(.bottom, 8)
                        }
                        contentArea
                    }
                    .frame(width: geo.size.width)   // hard-pin width — no horizontal overflow possible
                }
            }
        }
        .sheet(isPresented: $isCreationSheetPresented) {
            NewDocumentSheet(
                field: $draftField,
                name: $draftName,
                onConfirm: onConfirmNewDocument,
                onCancel: onCancelNewDocument,
                restorableSampleCount: restorableSampleCount,
                onRestoreSampleModels: onRestoreSampleModels
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
        // The system's large title and glass toolbar: the list scrolls under real glass.
        .navigationTitle("Biokinetics")
        .navigationSubtitle("& Dosimetry")
        .toolbar {
            ToolbarItem(placement: .barLeading) {
                Button(action: onOpenCredits) { Image(systemName: "info.circle") }
                    .accessibilityLabel("About")
            }
            ToolbarItem(placement: .barTrailing) {
                Button(action: onOpenFilePicker) { Label("Import", systemImage: "doc.badge.arrow.up") }
                    .buttonStyle(.glass)
                    .tint(.accentColor)
            }
            ToolbarSpacer(.fixed, placement: .barTrailing)
            ToolbarItem(placement: .barTrailing) {
                Button(action: onOpenCreationSheet) { Label("New", systemImage: "plus") }
                    .buttonStyle(.glass)
                    .tint(.accentColor)
            }
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
                // One glass card per model, apart from each other.
                VStack(spacing: 14) {
                    ForEach(cards) { card in
                        GCard(cornerRadius: 22) {
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
        // Adaptive, top-aligned: two columns on a landscape phone, three on a landscape iPad, and
        // cards of different heights start level.
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 320), spacing: 20, alignment: .top)],
            alignment: .leading,
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - HomeListRow (compact flat-list card)

private struct HomeListRow: View {
    let card: HomeFeature.DocumentCard
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
                    HalfLifeTag {
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
                if !label.isEmpty { Text(label).font(.system(size: 15.5, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8) }
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
    let card: HomeFeature.DocumentCard
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
                        HalfLifeTag {
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
                            .lineLimit(4)
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
                if !label.isEmpty {
                    Text(label).font(.system(size: 14.5, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
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

// MARK: - HalfLifeTag

/// A quiet capsule for a value inside a glass card: glass on glass muddies both.
private struct HalfLifeTag<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content.background(Capsule().fill(.quaternary.opacity(0.5)))
    }
}

// MARK: - Toolbar placements

private extension ToolbarItemPlacement {
    /// The bar's leading / trailing edge on iOS; the package's macOS build (tests) takes the
    /// nearest equivalent.
    static var barLeading: ToolbarItemPlacement {
        #if os(iOS)
            .topBarLeading
        #else
            .navigation
        #endif
    }

    static var barTrailing: ToolbarItemPlacement {
        #if os(iOS)
            .topBarTrailing
        #else
            .primaryAction
        #endif
    }
}
