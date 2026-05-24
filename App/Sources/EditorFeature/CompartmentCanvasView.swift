import AppDomain
import SwiftUI

// MARK: - CompartmentCanvasView

/// Zoomable, pannable canvas showing glass compartment nodes and link arrows.
///
/// Gestures:
/// - Tap a compartment: select it (or step through link-creation flow)
/// - Drag a compartment: move it
/// - Two-finger pan: pan the canvas
/// - Pinch: zoom the canvas
struct CompartmentCanvasView: View {
    let viewModel: EditorFeature.ViewModel

    @GestureState private var panDelta: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0

    private var effectiveOffset: CGSize {
        CGSize(
            width:  baseOffset.width  + panDelta.width,
            height: baseOffset.height + panDelta.height
        )
    }
    private var effectiveScale: CGFloat { baseScale * pinchScale }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Canvas background + dot grid
                canvasBackground(size: geo.size)

                // Link arrows (drawn below compartments)
                ForEach(viewModel.links) { link in
                    let from = nodePosition(for: link.fromId)
                    let to   = nodePosition(for: link.toId)
                    LinkArrow(
                        from: from, to: to,
                        rate: link.rate,
                        kLabel: "K\(link.id + 1)",
                        showLabel: viewModel.showKValues,
                        isSelected: viewModel.selectedLinkIndex == link.id,
                        tint: link.fromTint
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if viewModel.linkingState != .idle { return }
                        viewModel.dispatch(.selectLink(link.id))
                    }
                }

                // Compartment nodes
                ForEach(viewModel.compartments) { comp in
                    CompartmentNode(
                        comp: comp,
                        isLinkingTarget: viewModel.linkingState != .idle
                    )
                    .position(x: comp.x, y: comp.y)
                    .onTapGesture {
                        if viewModel.linkingState != .idle {
                            viewModel.dispatch(.linkStep(comp.id))
                        } else {
                            viewModel.dispatch(.selectCompartment(comp.id))
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                let newX = comp.x + val.translation.width  / effectiveScale
                                let newY = comp.y + val.translation.height / effectiveScale
                                viewModel.dispatch(.moveCompartment(id: comp.id, x: newX, y: newY))
                            }
                    )
                }
            }
            .frame(width: 900, height: 620)
            .scaleEffect(effectiveScale)
            .offset(
                x: effectiveOffset.width  + geo.size.width  / 2 - 450,
                y: effectiveOffset.height + geo.size.height / 2 - 310
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            // Two-finger pan
            .gesture(
                DragGesture(minimumDistance: 4)
                    .updating($panDelta) { val, state, _ in state = val.translation }
                    .onEnded { val in
                        baseOffset = CGSize(
                            width:  baseOffset.width  + val.translation.width,
                            height: baseOffset.height + val.translation.height
                        )
                    }
            )
            // Pinch to zoom
            .gesture(
                MagnificationGesture()
                    .updating($pinchScale) { val, state, _ in state = val }
                    .onEnded { val in
                        baseScale = max(0.2, min(5.0, baseScale * val))
                    }
            )
            // Double-tap to reset
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    baseOffset = .zero
                    baseScale  = 1.0
                }
            }
        }
        .clipped()
    }

    // MARK: - Helpers

    private func nodePosition(for id: String) -> CGPoint {
        guard let comp = viewModel.compartments.first(where: { $0.id == id }) else {
            return CGPoint(x: 450, y: 310)
        }
        return CGPoint(x: comp.x, y: comp.y)
    }

    @ViewBuilder
    private func canvasBackground(size: CGSize) -> some View {
        // Dot grid
        Canvas { ctx, sz in
            let spacing: CGFloat = 28
            let cols = Int(sz.width  / spacing) + 2
            let rows = Int(sz.height / spacing) + 2
            for col in 0...cols {
                for row in 0...rows {
                    let x = CGFloat(col) * spacing
                    let y = CGFloat(row) * spacing
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                             with: .color(.primary.opacity(0.07)))
                }
            }
        }
        .frame(width: 900, height: 620)
    }
}

// MARK: - CompartmentNode

private struct CompartmentNode: View {
    let comp: EditorFeature.ViewModel.CompartmentRow
    let isLinkingTarget: Bool

    @Environment(\.colorScheme) private var colorScheme
    private var dark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            // Glass base fill
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(comp.tint.fillColor(dark: dark).opacity(0.22))

            // Top glossy highlight (meniscus)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.55), location: 0.0),
                            .init(color: .white.opacity(0.0),  location: 0.52),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Inner tinted glow (bottom-weighted)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: comp.tint.fillColor(dark: dark).opacity(0.0),  location: 0.3),
                            .init(color: comp.tint.fillColor(dark: dark).opacity(0.18), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Thin top-edge meniscus border
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(dark ? 0.5 : 0.7), location: 0.0),
                            .init(color: comp.tint.strokeColor(dark: dark).opacity(0.5), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )

            // Content
            VStack(spacing: 3) {
                Text(comp.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(comp.tint.textColor(dark: dark))
                    .lineLimit(1)

                // Flag pills
                HStack(spacing: 4) {
                    if comp.follow  { flagDot(color: .blue)   }
                    if comp.dispose { flagDot(color: .orange) }
                    if comp.intake  { flagDot(color: .green)  }
                }
            }
            .padding(.horizontal, 8)

            // Selection ring
            if comp.isSelected {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(comp.tint.badgeColor(dark: dark), lineWidth: 2)
            }

            // Linking highlight pulse
            if isLinkingTarget && !comp.isSelected {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5)
            }
        }
        .frame(width: 92, height: 54)
        .shadow(
            color: comp.isSelected
                ? comp.tint.selectionGlow(dark: dark)
                : .clear,
            radius: 10
        )
        .scaleEffect(comp.isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: comp.isSelected)
    }

    private func flagDot(color: Color) -> some View {
        Circle()
            .fill(color.opacity(0.7))
            .frame(width: 5, height: 5)
    }
}

// MARK: - LinkArrow

private struct LinkArrow: View {
    let from: CGPoint
    let to: CGPoint
    let rate: Double
    let kLabel: String
    let showLabel: Bool
    let isSelected: Bool
    let tint: CompartmentTint

    @Environment(\.colorScheme) private var colorScheme
    private var dark: Bool { colorScheme == .dark }

    var body: some View {
        Canvas { ctx, _ in
            let path = arrowPath(from: from, to: to)
            let color = isSelected
                ? tint.badgeColor(dark: dark)
                : Color.primary.opacity(0.3)
            ctx.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: isSelected ? 1.8 : 1.2,
                                         lineCap: .round, lineJoin: .round))
            // Arrowhead
            let head = arrowheadPath(from: from, to: to)
            ctx.fill(head, with: .color(color))
        }
        .overlay {
            if showLabel || isSelected {
                let mid = midpoint(from: from, to: to)
                Text(kLabel)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(tint.badgeColor(dark: dark))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.regularMaterial, in: Capsule())
                    .position(x: mid.x, y: mid.y - 10)
            }
        }
        .frame(width: 900, height: 620)
        .allowsHitTesting(false)
    }

    private func arrowPath(from: CGPoint, to: CGPoint) -> Path {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return Path() }
        let ux = dx / len, uy = dy / len
        // Start/end at compartment edge (46 pts = half-width)
        let startX = from.x + ux * 46, startY = from.y + uy * 27
        let endX   = to.x   - ux * 46, endY   = to.y   - uy * 27
        var path = Path()
        path.move(to: CGPoint(x: startX, y: startY))
        path.addLine(to: CGPoint(x: endX, y: endY))
        return path
    }

    private func arrowheadPath(from: CGPoint, to: CGPoint) -> Path {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return Path() }
        let ux = dx / len, uy = dy / len
        let tipX = to.x - ux * 46, tipY = to.y - uy * 27
        let nx = -uy, ny = ux
        let size: CGFloat = 7
        var path = Path()
        path.move(to: CGPoint(x: tipX, y: tipY))
        path.addLine(to: CGPoint(x: tipX - ux * size + nx * size * 0.5,
                                  y: tipY - uy * size + ny * size * 0.5))
        path.addLine(to: CGPoint(x: tipX - ux * size - nx * size * 0.5,
                                  y: tipY - uy * size - ny * size * 0.5))
        path.closeSubpath()
        return path
    }

    private func midpoint(from: CGPoint, to: CGPoint) -> CGPoint {
        CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
    }
}
