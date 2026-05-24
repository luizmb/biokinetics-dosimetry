import AppDomain
import SwiftRexArchitecture
import SwiftUI

// MARK: - EditorView

@BoundTo(EditorFeature.self)
public struct EditorView: View {
    @Environment(\.horizontalSizeClass) private var hSize

    public var body: some View {
        HStack(spacing: 0) {
            // Left panel – compartment list
            if viewModel.isLeftPanelVisible {
                CompartmentListPanel(viewModel: viewModel)
                    .frame(width: 220)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                reopenStrip(edge: .leading) { viewModel.dispatch(.toggleLeftPanel) }
            }

            Divider()

            // Canvas
            CompartmentCanvasView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Right panel – inspector
            if viewModel.isRightPanelVisible {
                InspectorPanel(viewModel: viewModel)
                    .frame(width: 260)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                reopenStrip(edge: .trailing) { viewModel.dispatch(.toggleRightPanel) }
            }
        }
        .background(Color.platformGroupedBackground.ignoresSafeArea())
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: viewModel.isLeftPanelVisible)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: viewModel.isRightPanelVisible)
        .navigationTitle(viewModel.documentName)
        .inlineNavigationTitle()
        .toolbar { toolbarContent }
        .overlay(linkingBanner, alignment: .top)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .platformNavigationLeading) {
            halfLifeBadge
        }
        ToolbarItemGroup(placement: .platformNavigationTrailing) {
            // + Compartment picker
            addCompartmentMenu

            // Link mode button
            Button {
                if viewModel.linkingState == .idle {
                    viewModel.dispatch(.beginLinking)
                } else {
                    viewModel.dispatch(.cancelLinking)
                }
            } label: {
                Label("Link", systemImage: "arrow.triangle.branch")
            }
            .tint(viewModel.linkingState != .idle ? .accentColor : nil)

            // K-values toggle
            Toggle(isOn: Binding(
                get: { viewModel.showKValues },
                set: { _ in viewModel.dispatch(.toggleKValues) }
            )) {
                Label("K-values", systemImage: viewModel.showKValues ? "eye" : "eye.slash")
            }
            .toggleStyle(.button)

            // Panel toggles (Xcode-style)
            panelToggleButton(side: .leading, isVisible: viewModel.isLeftPanelVisible) {
                viewModel.dispatch(.toggleLeftPanel)
            }
            panelToggleButton(side: .trailing, isVisible: viewModel.isRightPanelVisible) {
                viewModel.dispatch(.toggleRightPanel)
            }
        }
    }

    // MARK: - Add compartment menu

    private var addCompartmentMenu: some View {
        Menu {
            ForEach(CompartmentTint.allCases, id: \.self) { tint in
                Button {
                    viewModel.dispatch(.addCompartment(tint))
                } label: {
                    Label(tint.defaultName, systemImage: "square.fill")
                }
            }
        } label: {
            Label("Add", systemImage: "plus.square")
        }
    }

    private var halfLifeBadge: some View {
        Group {
            if viewModel.halfLife > 0 {
                Text("T½ \(viewModel.halfLife.formatted(.number.precision(.fractionLength(1)))) d")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    // MARK: - Linking banner

    @ViewBuilder
    private var linkingBanner: some View {
        if viewModel.linkingState != .idle {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch")
                Text(viewModel.linkingState == .awaitingFrom
                     ? "Tap the source compartment"
                     : "Now tap the destination compartment")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button("Cancel") { viewModel.dispatch(.cancelLinking) }
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(), value: viewModel.linkingState)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func panelToggleButton(
        side: HorizontalEdge,
        isVisible: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: side == .leading
                  ? "sidebar.left"
                  : "sidebar.right")
                .symbolVariant(isVisible ? .fill : .none)
        }
        .tint(isVisible ? .accentColor : .secondary)
    }

    @ViewBuilder
    private func reopenStrip(edge: Edge, action: @escaping () -> Void) -> some View {
        let isLeft = edge == .leading
        Button(action: action) {
            Image(systemName: isLeft ? "chevron.right" : "chevron.left")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 18)
        .frame(maxHeight: .infinity)
        .background(.quaternary)
    }
}
