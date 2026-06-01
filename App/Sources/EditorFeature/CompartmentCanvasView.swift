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
    let compartments: [EditorFeature.ViewModel.CompartmentRow]
    let links:        [EditorFeature.ViewModel.LinkRow]
    let selectedCompartmentId: String?
    let selectedLinkIndex: Int?
    let showKValues: Bool
    let isLinking:   Bool
    let canvasOffsetX: Double
    let canvasOffsetY: Double
    let canvasScale:   Double
    let compartmentDragOriginId: String?
    let compartmentDragOriginX:  Double
    let compartmentDragOriginY:  Double
    let canvasPanOriginX:       Double?
    let canvasPanOriginY:       Double?
    let canvasPinchOriginScale: Double?
    var onSelectCompartment: (String?) -> Void
    var onSelectLink:         (Int?) -> Void
    var onMoveCompartment:    (String, Double, Double) -> Void
    var onBeginCompartmentDrag: (String, Double, Double) -> Void
    var onEndCompartmentDrag:   () -> Void
    var onBeginCanvasPan:       (Double, Double) -> Void
    var onEndCanvasPan:         () -> Void
    var onBeginCanvasPinch:     (Double) -> Void
    var onEndCanvasPinch:       () -> Void
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
                // ── Fixed dot-grid backdrop ────────────────────────────────────
                dotGrid(size: geo.size)

                // ── Link arrows — Path shapes in screen-space ──────────────────
                ForEach(links.filter { isLinkVisible($0, in: viewport) }) { link in
                    let from   = screenPt(nodePos(link.fromId), hw: hw, hh: hh, s: s, ox: ox, oy: oy)
                    let to     = screenPt(nodePos(link.toId),   hw: hw, hh: hh, s: s, ox: ox, oy: oy)
                    let srcSz  = nodeSize(link.fromId)
                    let dstSz  = nodeSize(link.toId)
                    let sel    = selectedLinkIndex == link.id
                    let col: Color = sel
                        ? link.fromTint.indicator(dark: isDark)
                        : Color.primary.opacity(0.35)

                    screenArrowLine(from: from, to: to, srcSize: srcSz, dstSize: dstSz, scale: s)
                        .stroke(col, style: StrokeStyle(lineWidth: sel ? 1.8 : 1.2, lineCap: .round))
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
                ForEach(compartments) { comp in
                    let sz = nodeSize(comp.id)
                    let sp = screenPt(CGPoint(x: comp.x, y: comp.y), hw: hw, hh: hh, s: s, ox: ox, oy: oy)
                    CompartmentNode(comp: comp, isLinkingTarget: isLinking, size: sz)
                        .scaleEffect(s)
                        .position(x: sp.x, y: sp.y)
                        .highPriorityGesture(TapGesture().onEnded { onSelectCompartment(comp.id) })
                        .gesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { val in
                                    let set = compartmentDragOriginId == comp.id
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
                                .onEnded { _ in onEndCompartmentDrag() }
                        )
                }
            }
            .contentShape(Rectangle())
            // Gestures live on the same ZStack that contains the nodes so child
            // drag gestures (node move) correctly suppress the pan gesture.
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { val in
                        let panSet = canvasPanOriginX != nil
                        let panOX = canvasPanOriginX ?? canvasOffsetX
                        let panOY = canvasPanOriginY ?? canvasOffsetY
                        if !panSet { onBeginCanvasPan(canvasOffsetX, canvasOffsetY) }
                        onSetCanvasTransform(
                            panOX + Double(val.translation.width),
                            panOY + Double(val.translation.height),
                            canvasScale)
                    }
                    .onEnded { _ in onEndCanvasPan() }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { val in
                        let set = canvasPinchOriginScale != nil
                        let os  = canvasPinchOriginScale ?? canvasScale
                        if !set { onBeginCanvasPinch(canvasScale) }
                        onSetCanvasTransform(canvasOffsetX, canvasOffsetY,
                                             max(0.2, min(5.0, os * Double(val))))
                    }
                    .onEnded { _ in onEndCanvasPinch() }
            )
            .onTapGesture(count: 2) { onSetCanvasTransform(0, 0, 1) }
        }
        .clipped()
    }

    // MARK: - Helpers

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
        let connCount = links.filter { $0.fromId == id || $0.toId == id }.count
        let trimmed   = comp.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let textW     = CGFloat(trimmed.count) * 6.5 + 20
        let baseW     = max(72.0, textW)
        // sqrt-based factor so very connected nodes grow but don't become huge
        let factor    = min(CGFloat(1.0 + max(0.0, sqrt(Double(max(0, connCount - 2))) * 0.12)), 1.8)
        return CGSize(
            width:  min(max(baseW, 84 * factor), 200),
            height: max(38.0, min(48 * factor, 78))
        )
    }

    private func isLinkVisible(_ link: EditorFeature.ViewModel.LinkRow, in vp: CGRect) -> Bool {
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

    @ViewBuilder
    private func dotGrid(size: CGSize) -> some View {
        Canvas { ctx, sz in
            let sp: CGFloat = 28
            for col in 0...Int(sz.width/sp)+2 {
                for row in 0...Int(sz.height/sp)+2 {
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: CGFloat(col)*sp-1, y: CGFloat(row)*sp-1,
                                               width: 2, height: 2)),
                        with: .color(.primary.opacity(0.07)))
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - CompartmentNode

private struct CompartmentNode: View {
    let comp: EditorFeature.ViewModel.CompartmentRow
    let isLinkingTarget: Bool
    let size: CGSize
    @Environment(\.colorScheme) private var colorScheme
    private var dark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(comp.tint.surfaceGradient(dark: dark))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(stops: [
                    .init(color: .white.opacity(dark ? 0.22 : 0.65), location: 0),
                    .init(color: .white.opacity(dark ? 0.06 : 0.18), location: 0.45),
                    .init(color: .clear, location: 1)],
                    startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(dark ? 0.18 : 0.85), lineWidth: 0.8)
                .blendMode(.screen)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(comp.isSelected ? comp.tint.indicator(dark: dark)
                                        : comp.tint.border(dark: dark),
                        lineWidth: comp.isSelected ? 1.6 : 0.8)
            VStack(spacing: 3) {
                Text(comp.name.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(comp.tint.foreground(dark: dark))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                HStack(spacing: 4) {
                    if comp.follow  { dot(.blue)   }
                    if comp.dispose { dot(.orange) }
                    if comp.intake  { dot(.green)  }
                }
            }
            .padding(.horizontal, 8)
            if isLinkingTarget && !comp.isSelected {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5)
            }
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: comp.isSelected ? comp.tint.selectionGlow(dark: dark) : .clear,
                radius: 10)
        .scaleEffect(comp.isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: comp.isSelected)
    }

    private func dot(_ c: Color) -> some View {
        Circle().fill(c.opacity(0.7)).frame(width: 5, height: 5)
    }
}
