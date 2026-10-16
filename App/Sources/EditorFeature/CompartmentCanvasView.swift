import AppDomain
import SwiftUI
import UIComponents

// MARK: - CompartmentCanvasView (pure)

/// All rendering is in SCREEN-SPACE so nothing ever extends outside the
/// viewport, eliminating every variant of the "drawingGroup clips off-screen
/// content" bug.
///
/// Coordinate mapping (canvas → screen):
///   sx = (cx - 450) * scale + geo.width/2  + offsetX
///   sy = (cy - 310) * scale + geo.height/2 + offsetY
///
/// The inverse gives the visible canvas rect used for culling.
struct CompartmentCanvasView: View {
    let compartments: [EditorFeature.CompartmentRow]
    let links:        [EditorFeature.LinkRow]
    let selectedCompartmentId: String?
    let selectedLinkIndex: Int?
    let showKValues: Bool
    let isLinking:   Bool
    let canvasOffsetX: Double
    let canvasOffsetY: Double
    let canvasScale:   Double
    let isPinching:    Bool
    let compartmentDragOriginId: String?
    let compartmentDragOriginX:  Double
    let compartmentDragOriginY:  Double
    var onSelectCompartment: (String?) -> Void
    var onSelectLink:         (Int?) -> Void
    var onMoveCompartment:    (String, Double, Double) -> Void
    var onBeginCompartmentDrag: (String, Double, Double) -> Void
    var onEndCompartmentDrag:   () -> Void
    var onCanvasTouches:        (EditorFeature.CanvasTouches) -> Void
    var onEndCanvasTouches:     () -> Void
    var onSetCanvasTransform:   (Double, Double, Double) -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private var scale: CGFloat { CGFloat(canvasScale) }

    var body: some View {
        GeometryReader { geo in
            let s  = scale
            let ox = CGFloat(canvasOffsetX), oy = CGFloat(canvasOffsetY)
            let hw = geo.size.width / 2, hh = geo.size.height / 2

            // Visible canvas rect — used only for culling.
            let vpX = Double(-hw - ox) / canvasScale + 450
            let vpY = Double(-hh - oy) / canvasScale + 310
            let viewport = CGRect(x: vpX, y: vpY,
                                  width: Double(geo.size.width)  / canvasScale,
                                  height: Double(geo.size.height) / canvasScale)

            ZStack {
                // ── Graph paper and soft colour fields for the glass to bend ───
                GlassBackdrop(origin: screenPt(.zero, hw: hw, hh: hh, s: s, ox: ox, oy: oy), scale: s)
                    .allowsHitTesting(false)

                // ── Intake arrows — bold arrows from above for intake compartments ──
                ForEach(compartments.filter { $0.intake }) { comp in
                    let sz  = nodeSize(comp.id)
                    let sp  = screenPt(CGPoint(x: comp.x, y: comp.y), hw: hw, hh: hh, s: s, ox: ox, oy: oy)
                    let len = sz.height * 0.55 * s          // ~half compartment height
                    let tail = CGPoint(x: sp.x, y: sp.y - sz.height/2*s - len)
                    let intakeColor = Color(hex: 0x34C759)

                    // Shaft
                    Path { p in
                        p.move(to: tail)
                        p.addLine(to: CGPoint(x: sp.x, y: sp.y - sz.height/2*s - 8))
                    }
                    .stroke(intakeColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .allowsHitTesting(false)

                    // Arrowhead (reuse existing helper)
                    screenArrowHead(from: tail, to: sp, dstSize: sz, scale: s)
                        .fill(intakeColor)
                        .allowsHitTesting(false)

                    // Fraction label
                    if comp.fraction > 0 {
                        Text(comp.fraction.formatted(.number.precision(.fractionLength(2))))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(intakeColor)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(.regularMaterial, in: Capsule())
                            .position(x: sp.x + sz.width/2*s*0.5 + 10,
                                      y: (tail.y + sp.y - sz.height/2*s) / 2)
                            .allowsHitTesting(false)
                    }

                    // Tap target — selects the compartment
                    Color.clear
                        .frame(width: 44, height: max(44, len))
                        .contentShape(Rectangle())
                        .position(x: sp.x, y: tail.y + len/2)
                        .highPriorityGesture(TapGesture().onEnded {
                            guard !isLinking else { return }
                            onSelectCompartment(comp.id)
                        })
                }

                // ── Link arrows — Path shapes in screen-space ──────────────────
                ForEach(links.filter { isLinkVisible($0, in: viewport) }) { link in
                    let from   = screenPt(nodePos(link.fromId), hw: hw, hh: hh, s: s, ox: ox, oy: oy)
                    let to     = screenPt(nodePos(link.toId),   hw: hw, hh: hh, s: s, ox: ox, oy: oy)
                    let srcSz  = nodeSize(link.fromId)
                    let dstSz  = nodeSize(link.toId)
                    let sel    = selectedLinkIndex == link.id
                    let col: Color = sel
                        ? link.fromTint.indicator(dark: isDark)
                        : Color.primary.opacity(0.5)

                    screenArrowLine(from: from, to: to, srcSize: srcSz, dstSize: dstSz, scale: s)
                        .stroke(col, style: StrokeStyle(lineWidth: sel ? 2 : 1.4, lineCap: .round))
                        .allowsHitTesting(false)

                    screenArrowHead(from: from, to: to, dstSize: dstSz, scale: s)
                        .fill(col)
                        .allowsHitTesting(false)
                }

                // ── K labels ──────────────────────────────────────────────────
                ForEach(links.filter {
                    isLinkVisible($0, in: viewport) && (showKValues || selectedLinkIndex == $0.id)
                }) { link in
                    let from = screenPt(nodePos(link.fromId), hw: hw, hh: hh, s: s, ox: ox, oy: oy)
                    let to   = screenPt(nodePos(link.toId),   hw: hw, hh: hh, s: s, ox: ox, oy: oy)
                    let mid  = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
                    Text("K\(link.id + 1)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(selectedLinkIndex == link.id
                                         ? link.fromTint.indicator(dark: isDark)
                                         : Color.secondary)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(.regularMaterial, in: Capsule())
                        .position(x: mid.x, y: mid.y - 12)
                        .allowsHitTesting(false)
                }

                // ── Link tap targets ──────────────────────────────────────────
                ForEach(links.filter { isLinkVisible($0, in: viewport) }) { link in
                    let from = screenPt(nodePos(link.fromId), hw: hw, hh: hh, s: s, ox: ox, oy: oy)
                    let to   = screenPt(nodePos(link.toId),   hw: hw, hh: hh, s: s, ox: ox, oy: oy)
                    let mid  = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
                    Color.clear
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .position(x: mid.x, y: mid.y)
                        .highPriorityGesture(TapGesture().onEnded {
                            guard !isLinking else { return }
                            onSelectLink(link.id)
                        })
                }

                // ── Compartment nodes — screen-space positioning ───────────────
                // One container for every node: a single glass render pass, and nodes dragged
                // over each other fuse into one piece of glass.
                GlassEffectContainer(spacing: 6) {
                ZStack {
                ForEach(compartments) { comp in
                    let sz = nodeSize(comp.id)
                    let sp = screenPt(CGPoint(x: comp.x, y: comp.y), hw: hw, hh: hh, s: s, ox: ox, oy: oy)
                    CompartmentNode(comp: comp, isLinkingTarget: isLinking, size: sz, scale: s, isPinching: isPinching)
                        // The node's own rounded shape is its touch area. Attached after
                        // `.position` (which fills the whole canvas) every node competed for every
                        // touch: overlapping nodes moved together and drags fought the pan.
                        .contentShape(RoundedRectangle(cornerRadius: 14 * s, style: .continuous))
                        // One gesture for tap and drag: a tap gesture beside the drag made every
                        // drag wait for the tap to fail (~200 ms) before the node moved. A release
                        // that never travelled 4 pt is the tap. High priority so a touch that
                        // starts on a node drags it rather than panning; measured in the canvas'
                        // space, which doesn't move with the node.
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.canvasSpace))
                                .onChanged { val in
                                    let set = compartmentDragOriginId == comp.id
                                    guard set || hypot(val.translation.width, val.translation.height) >= 4 else { return }
                                    let ox2 = set ? compartmentDragOriginX : comp.x
                                    let oy2 = set ? compartmentDragOriginY : comp.y
                                    if !set { onBeginCompartmentDrag(comp.id, comp.x, comp.y) }
                                    // translation is in screen units; divide by scale → canvas units
                                    onMoveCompartment(
                                        comp.id,
                                        ox2 + Double(val.translation.width  / s),
                                        oy2 + Double(val.translation.height / s)
                                    )
                                }
                                .onEnded { val in
                                    if hypot(val.translation.width, val.translation.height) < 4 {
                                        onSelectCompartment(comp.id)
                                    } else {
                                        onEndCompartmentDrag()
                                    }
                                }
                        )
                        .position(x: sp.x, y: sp.y)
                        // The node being dragged, or the selected one, sits on top, so it's the one
                        // a touch on overlapping nodes picks.
                        .zIndex(compartmentDragOriginId == comp.id ? 2 : comp.isSelected ? 1 : 0)
                }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .contentShape(Rectangle())
            .coordinateSpace(.named(Self.canvasSpace))
            // Gestures live on the same ZStack that contains the nodes so child
            // drag gestures (node move) correctly suppress the pan gesture.
            // Every finger's position, as it moves: SwiftUI's pinch reports neither where the
            // fingers are now nor lets a drag keep reporting under it, so the pair couldn't pan.
            // The view only forwards the points; the reducer pans by their centre and zooms by
            // their spread. Fires on first contact, with no recognition threshold to wait for.
            .gesture(
                SpatialEventGesture()
                    .onChanged { events in
                        let touches = Dictionary(
                            events.filter { $0.phase == .active }.map { ($0.id.hashValue, EditorFeature.CanvasPoint(x: Double($0.location.x), y: Double($0.location.y))) },
                            uniquingKeysWith: { first, _ in first }
                        )
                        onCanvasTouches(EditorFeature.CanvasTouches(touches: touches, viewCenter: EditorFeature.CanvasPoint(x: Double(hw), y: Double(hh))))
                    }
                    .onEnded { _ in onEndCanvasTouches() }
            )
            // Simultaneous, so the pinch never waits for a double tap to fail.
            .simultaneousGesture(TapGesture(count: 2).onEnded { onSetCanvasTransform(0, 0, 1) })
        }
        .clipped()
    }

    // MARK: - Helpers

    private static let canvasSpace = "compartmentCanvas"

    /// Converts a canvas-space point to screen-space.
    private func screenPt(_ p: CGPoint, hw: CGFloat, hh: CGFloat,
                           s: CGFloat, ox: CGFloat, oy: CGFloat) -> CGPoint {
        CGPoint(x: (p.x - 450) * s + hw + ox,
                y: (p.y - 310) * s + hh + oy)
    }

    private func nodePos(_ id: String) -> CGPoint {
        guard let c = compartments.first(where: { $0.id == id }) else {
            return CGPoint(x: 450, y: 310)
        }
        return CGPoint(x: c.x, y: c.y)
    }

    /// Dynamic node size in canvas units (before scale).
    /// Width tracks the name length; a sub-linear connection-count factor
    /// grows hub nodes proportionally without exploding for very connected ones.
    private func nodeSize(_ id: String) -> CGSize {
        guard let comp = compartments.first(where: { $0.id == id }) else {
            return CGSize(width: 84, height: 48)
        }
        let size = compartmentNodeSize(name: comp.name, linkCount: links.count { $0.fromId == id || $0.toId == id })
        return CGSize(width: size.width, height: size.height)
    }

    private func isLinkVisible(_ link: EditorFeature.LinkRow, in vp: CGRect) -> Bool {
        let f = nodePos(link.fromId), t = nodePos(link.toId)
        let bb = CGRect(x: min(f.x,t.x)-20, y: min(f.y,t.y)-20,
                        width: abs(t.x-f.x)+40, height: abs(t.y-f.y)+40)
        return vp.insetBy(dx: -100, dy: -100).intersects(bb)
    }

    // MARK: - Arrow geometry (screen-space, correct rectangle intersection)

    /// Distance from centre to the edge of a rectangle in direction (ux, uy).
    /// This is the correct formula for a rectangle — not an ellipse approximation.
    private func edgeDist(ux: CGFloat, uy: CGFloat, hw: CGFloat, hh: CGFloat) -> CGFloat {
        let ax = abs(ux), ay = abs(uy)
        if ax < 1e-6 { return hh }
        if ay < 1e-6 { return hw }
        return min(hw / ax, hh / ay)
    }

    private func screenArrowLine(from s: CGPoint, to e: CGPoint,
                                  srcSize: CGSize, dstSize: CGSize,
                                  scale: CGFloat) -> Path {
        let dx = e.x-s.x, dy = e.y-s.y, len = sqrt(dx*dx+dy*dy)
        guard len > 1 else { return Path() }
        let ux = dx/len, uy = dy/len
        let tSrc = edgeDist(ux: ux, uy: uy, hw: srcSize.width/2*scale, hh: srcSize.height/2*scale)
        let tDst = edgeDist(ux: ux, uy: uy, hw: dstSize.width/2*scale, hh: dstSize.height/2*scale)
        var p = Path()
        p.move(to:    CGPoint(x: s.x + ux*tSrc, y: s.y + uy*tSrc))
        p.addLine(to: CGPoint(x: e.x - ux*tDst, y: e.y - uy*tDst))
        return p
    }

    private func screenArrowHead(from s: CGPoint, to e: CGPoint,
                                  dstSize: CGSize, scale: CGFloat) -> Path {
        let dx = e.x-s.x, dy = e.y-s.y, len = sqrt(dx*dx+dy*dy)
        guard len > 1 else { return Path() }
        let ux = dx/len, uy = dy/len, nx = -uy, ny = ux
        let tDst = edgeDist(ux: ux, uy: uy, hw: dstSize.width/2*scale, hh: dstSize.height/2*scale)
        let tip = CGPoint(x: e.x - ux*tDst, y: e.y - uy*tDst)
        let sz: CGFloat = 7
        var p = Path()
        p.move(to: tip)
        p.addLine(to: CGPoint(x: tip.x-ux*sz+nx*sz*0.5, y: tip.y-uy*sz+ny*sz*0.5))
        p.addLine(to: CGPoint(x: tip.x-ux*sz-nx*sz*0.5, y: tip.y-uy*sz-ny*sz*0.5))
        p.closeSubpath()
        return p
    }
}

// MARK: - CompartmentNode

private struct CompartmentNode: View {
    let comp: EditorFeature.CompartmentRow
    let isLinkingTarget: Bool
    /// In canvas units.
    let size: CGSize
    let scale: CGFloat
    /// While two fingers zoom, every node changes size each frame and rebuilding the glass at each
    /// size stalls the pinch; the nodes are plain cards until the fingers lift, then settle back.
    let isPinching: Bool
    @Environment(\.colorScheme) private var colorScheme
    private var dark: Bool { colorScheme == .dark }

    /// The glass is cut at the node's on-screen size and only the content inside is scaled: a
    /// `scaleEffect` over the glass grew the glass while its content stayed drawn at 1×.
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
        ZStack {
            label
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
        }
        .frame(width: size.width * scale, height: size.height * scale)
        .clipShape(shape)
        .background { if isPinching { shape.fill(.regularMaterial) } }
        .glassEffect(isPinching ? .identity : .clear.tint(glassTint).interactive(), in: shape)
        .animation(.easeOut(duration: 0.2), value: isPinching)
    }

    private var label: some View {
        VStack(spacing: 4) {
            Text(comp.name.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            HStack(spacing: 4) {
                if comp.follow { dot(.blue) }
                if comp.dispose { dot(.orange) }
                if comp.intake { dot(.green) }
            }
        }
        .padding(.horizontal, 8)
    }

    /// No border: the glass edge is the outline. Selection and linking show as a deeper tint.
    private var glassTint: Color {
        if isLinkingTarget, !comp.isSelected { return Color.accentColor.opacity(0.25) }
        return comp.tint.indicator(dark: dark).opacity(comp.isSelected ? 0.35 : 0.1)
    }

    private func dot(_ c: Color) -> some View {
        Circle().fill(c.opacity(0.8)).frame(width: 6, height: 6)
    }
}
