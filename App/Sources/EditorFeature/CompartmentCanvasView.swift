import AppDomain
import SwiftUI
import UIComponents

// MARK: - CompartmentCanvasView (pure)

/// Zoomable, pannable canvas showing glass compartment nodes and link arrows.
///
/// Gestures:
/// - Tap a compartment: select it (or step through link-creation flow)
/// - Drag a compartment: move it
/// - Two-finger pan: pan the canvas
/// - Pinch: zoom the canvas
struct CompartmentCanvasView: View {
    // MARK: Props
    let compartments: [EditorFeature.ViewModel.CompartmentRow]
    let links: [EditorFeature.ViewModel.LinkRow]
    let selectedCompartmentId: String?
    let selectedLinkIndex: Int?
    let showKValues: Bool
    let isLinking: Bool
    let canvasOffsetX: Double
    let canvasOffsetY: Double
    let canvasScale: Double
    let compartmentDragOriginId: String?
    let compartmentDragOriginX: Double
    let compartmentDragOriginY: Double
    let canvasPanOriginX: Double?
    let canvasPanOriginY: Double?
    let canvasPinchOriginScale: Double?
    var onSelectCompartment: (String?) -> Void
    var onSelectLink: (Int?) -> Void
    var onMoveCompartment: (String, Double, Double) -> Void
    var onBeginCompartmentDrag: (String, Double, Double) -> Void
    var onEndCompartmentDrag: () -> Void
    var onBeginCanvasPan: (Double, Double) -> Void
    var onEndCanvasPan: () -> Void
    var onBeginCanvasPinch: (Double) -> Void
    var onEndCanvasPinch: () -> Void
    var onSetCanvasTransform: (Double, Double, Double) -> Void

    // effectiveScale is needed by compartment drag calculations; read from ViewState.
    private var effectiveScale: CGFloat { CGFloat(canvasScale) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Fixed backdrop: fills the full GeometryReader and never pans.
                // This ensures the dot grid is always visible regardless of canvas offset.
                dotGrid(size: geo.size)

                // Panning/scaling frame: contains only the canvas content (links + nodes).
                // The backdrop is intentionally excluded so it stays fixed.
                ZStack {
                    // Link arrows
                    ForEach(links) { link in
                        let from = nodePosition(for: link.fromId)
                        let to   = nodePosition(for: link.toId)
                        LinkArrow(
                            from: from, to: to,
                            rate: link.rate,
                            kLabel: "K\(link.id + 1)",
                            showLabel: showKValues,
                            isSelected: selectedLinkIndex == link.id,
                            tint: link.fromTint
                        )
                        .contentShape(Rectangle())
                        .highPriorityGesture(TapGesture().onEnded {
                            guard !isLinking else { return }
                            onSelectLink(link.id)
                        })
                    }

                    // Compartment nodes
                    ForEach(compartments) { comp in
                        CompartmentNode(comp: comp, isLinkingTarget: isLinking)
                            .position(x: comp.x, y: comp.y)
                            .highPriorityGesture(TapGesture().onEnded { onSelectCompartment(comp.id) })
                            .gesture(
                                DragGesture(minimumDistance: 4)
                                    .onChanged { val in
                                        let isDragOriginSet = compartmentDragOriginId == comp.id
                                        let originX = isDragOriginSet ? compartmentDragOriginX : comp.x
                                        let originY = isDragOriginSet ? compartmentDragOriginY : comp.y
                                        if !isDragOriginSet {
                                            onBeginCompartmentDrag(comp.id, comp.x, comp.y)
                                        }
                                        let newX = originX + Double(val.translation.width  / effectiveScale)
                                        let newY = originY + Double(val.translation.height / effectiveScale)
                                        onMoveCompartment(comp.id, newX, newY)
                                    }
                                    .onEnded { _ in onEndCompartmentDrag() }
                            )
                    }
                }
                .frame(width: 900, height: 620)
                .scaleEffect(CGFloat(canvasScale))
                .offset(
                    x: CGFloat(canvasOffsetX) + geo.size.width  / 2 - 450,
                    y: CGFloat(canvasOffsetY) + geo.size.height / 2 - 310
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .contentShape(Rectangle())
            // Two-finger pan: same store-origin pattern as compartment drag.
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { val in
                        let isPanOriginSet = canvasPanOriginX != nil
                        let originX = canvasPanOriginX ?? canvasOffsetX
                        let originY = canvasPanOriginY ?? canvasOffsetY
                        if !isPanOriginSet {
                            onBeginCanvasPan(canvasOffsetX, canvasOffsetY)
                        }
                        let newX = originX + Double(val.translation.width)
                        let newY = originY + Double(val.translation.height)
                        onSetCanvasTransform(newX, newY, canvasScale)
                    }
                    .onEnded { _ in onEndCanvasPan() }
            )
            // Pinch to zoom: same store-origin pattern.
            .gesture(
                MagnificationGesture()
                    .onChanged { val in
                        let isPinchOriginSet = canvasPinchOriginScale != nil
                        let originScale = canvasPinchOriginScale ?? canvasScale
                        if !isPinchOriginSet {
                            onBeginCanvasPinch(canvasScale)
                        }
                        let newScale = max(0.2, min(5.0, originScale * Double(val)))
                        onSetCanvasTransform(canvasOffsetX, canvasOffsetY, newScale)
                    }
                    .onEnded { _ in onEndCanvasPinch() }
            )
            .onTapGesture(count: 2) {
                onSetCanvasTransform(0, 0, 1)
            }
        }
        .clipped()
    }

    private func nodePosition(for id: String) -> CGPoint {
        guard let comp = compartments.first(where: { $0.id == id }) else {
            return CGPoint(x: 450, y: 310)
        }
        return CGPoint(x: comp.x, y: comp.y)
    }

    /// Fixed dot-grid backdrop. Renders at the full GeometryReader size so it
    /// always covers the visible canvas area, regardless of pan or zoom offset.
    @ViewBuilder
    private func dotGrid(size: CGSize) -> some View {
        Canvas { ctx, sz in
            let spacing: CGFloat = 28
            let cols = Int(sz.width  / spacing) + 2
            let rows = Int(sz.height / spacing) + 2
            for col in 0...cols {
                for row in 0...rows {
                    let x = CGFloat(col) * spacing
                    let y = CGFloat(row) * spacing
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                        with: .color(.primary.opacity(0.07))
                    )
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - CompartmentNode (pure)

private struct CompartmentNode: View {
    let comp: EditorFeature.ViewModel.CompartmentRow
    let isLinkingTarget: Bool

    @Environment(\.colorScheme) private var colorScheme
    private var dark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            // Glass base: gradient body
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(comp.tint.surfaceGradient(dark: dark))

            // Top gloss sheen
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(dark ? 0.22 : 0.65), location: 0.0),
                            .init(color: .white.opacity(dark ? 0.06 : 0.18), location: 0.45),
                            .init(color: .clear, location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Inner tinted glow (bottom-weighted)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [comp.tint.background(dark: dark).opacity(dark ? 0.28 : 0.16), .clear],
                        center: .bottom, startRadius: 0, endRadius: 50
                    )
                )

            // Top-edge highlight
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(dark ? 0.18 : 0.85), lineWidth: 0.8)
                .blendMode(.screen)

            // Stroke border
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(comp.isSelected
                        ? comp.tint.indicator(dark: dark)
                        : comp.tint.border(dark: dark),
                        lineWidth: comp.isSelected ? 1.6 : 0.8)

            // Content
            VStack(spacing: 3) {
                Text(comp.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(comp.tint.foreground(dark: dark))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if comp.follow  { flagDot(.blue)   }
                    if comp.dispose { flagDot(.orange) }
                    if comp.intake  { flagDot(.green)  }
                }
            }
            .padding(.horizontal, 8)

            // Linking highlight
            if isLinkingTarget && !comp.isSelected {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5)
            }
        }
        .frame(width: 92, height: 54)
        .shadow(
            color: comp.isSelected ? comp.tint.selectionGlow(dark: dark) : .clear,
            radius: 10
        )
        .scaleEffect(comp.isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: comp.isSelected)
    }

    private func flagDot(_ color: Color) -> some View {
        Circle().fill(color.opacity(0.7)).frame(width: 5, height: 5)
    }
}

// MARK: - LinkArrow (pure)

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
                ? tint.indicator(dark: dark)
                : Color.primary.opacity(0.3)
            ctx.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: isSelected ? 1.8 : 1.2,
                                         lineCap: .round, lineJoin: .round))
            let head = arrowheadPath(from: from, to: to)
            ctx.fill(head, with: .color(color))
        }
        .overlay {
            if showLabel || isSelected {
                let mid = midpoint(from: from, to: to)
                Text(kLabel)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(tint.indicator(dark: dark))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.regularMaterial, in: Capsule())
                    .position(x: mid.x, y: mid.y - 10)
            }
        }
        .frame(width: 900, height: 620)
        .allowsHitTesting(false)
    }

    private func arrowPath(from s: CGPoint, to e: CGPoint) -> Path {
        let dx = e.x - s.x, dy = e.y - s.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return Path() }
        let ux = dx / len, uy = dy / len
        let startX = s.x + ux * 46, startY = s.y + uy * 27
        let endX   = e.x - ux * 46, endY   = e.y - uy * 27
        var path = Path()
        path.move(to: CGPoint(x: startX, y: startY))
        path.addLine(to: CGPoint(x: endX, y: endY))
        return path
    }

    private func arrowheadPath(from s: CGPoint, to e: CGPoint) -> Path {
        let dx = e.x - s.x, dy = e.y - s.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return Path() }
        let ux = dx / len, uy = dy / len
        let tipX = e.x - ux * 46, tipY = e.y - uy * 27
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

    private func midpoint(from a: CGPoint, to b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}
