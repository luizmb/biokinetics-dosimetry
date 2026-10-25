import EditorFeature
import Foundation
import SwiftRex
import SwiftRexTesting
import Testing

/// Pan and pinch: the view reports finger positions, the reducer pans by their centre and zooms by
/// their spread.
@Suite("Canvas pan and pinch")
@MainActor
struct CanvasGestureTests {
    private typealias Point = EditorFeature.CanvasPoint
    private let center = Point(x: 200, y: 400)

    private func touches(_ points: [Int: Point]) -> EditorFeature.CanvasTouches {
        EditorFeature.CanvasTouches(touches: points, viewCenter: center)
    }

    /// Screen point of canvas point `c` under `t` (the canvas view's mapping).
    private func screen(_ c: Point, _ t: EditorFeature.CanvasTransform) -> Point {
        Point(x: (c.x - 450) * t.scale + center.x + t.offset.x, y: (c.y - 310) * t.scale + center.y + t.offset.y)
    }

    private func canvas(_ p: Point, _ t: EditorFeature.CanvasTransform) -> Point {
        Point(x: (p.x - center.x - t.offset.x) / t.scale + 450, y: (p.y - center.y - t.offset.y) / t.scale + 310)
    }

    @Test func oneFingerPans() {
        let session = EditorFeature.CanvasTouchSession(
            start: .init(offset: Point(x: 10, y: -5), scale: 1.5), touches: [1: Point(x: 100, y: 100)]
        )
        let moved = EditorFeature.canvasTransform(session, touches([1: Point(x: 130, y: 112)]))
        #expect(moved == .init(offset: Point(x: 40, y: 7), scale: 1.5))
    }

    @Test func twoFingersMovingTogetherPanWithoutZooming() {
        let session = EditorFeature.CanvasTouchSession(
            start: .init(offset: Point(x: 0, y: 0), scale: 1), touches: [1: Point(x: 100, y: 300), 2: Point(x: 300, y: 300)]
        )
        let moved = EditorFeature.canvasTransform(session, touches([1: Point(x: 150, y: 260), 2: Point(x: 350, y: 260)]))
        #expect(moved == .init(offset: Point(x: 50, y: -40), scale: 1))
    }

    /// The canvas point between the fingers when they went down stays between them, wherever the
    /// pair has moved, while their spread sets the zoom.
    @Test func spreadingZoomsAroundTheirCentreWhileItMoves() {
        let start = EditorFeature.CanvasTransform(offset: Point(x: 25, y: -40), scale: 1.2)
        let session = EditorFeature.CanvasTouchSession(start: start, touches: [1: Point(x: 250, y: 300), 2: Point(x: 350, y: 300)])
        let underCentre = canvas(Point(x: 300, y: 300), start)
        // Twice as far apart, and the pair moved 40 pt down.
        let after = EditorFeature.canvasTransform(session, touches([1: Point(x: 200, y: 340), 2: Point(x: 400, y: 340)]))
        #expect(abs(after.scale - 2.4) < 1e-12)
        let there = screen(underCentre, after)
        #expect(abs(there.x - 300) < 1e-9 && abs(there.y - 340) < 1e-9)
    }

    /// A finger added mid-gesture starts a new session from where the canvas is: no jump.
    @Test func aSecondFingerReBasesWithoutAJump() {
        var initial = EditorFeature.State()
        initial.canvasOffset = Point(x: 10, y: 10)
        let store = TestStore(initial: initial, behavior: EditorFeature.behavior(), environment: EditorFeature.Environment.test(newId: { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! }))
        store.dispatch(.canvasTouchesChanged(touches([1: Point(x: 100, y: 100)]))) {
            $0.canvasTouchSession = .init(start: .init(offset: Point(x: 10, y: 10), scale: 1), touches: [1: Point(x: 100, y: 100)])
        }
        store.dispatch(.canvasTouchesChanged(touches([1: Point(x: 120, y: 100)]))) {
            $0.canvasOffset = Point(x: 30, y: 10)
        }
        store.dispatch(.canvasTouchesChanged(touches([1: Point(x: 120, y: 100), 2: Point(x: 220, y: 100)]))) {
            $0.canvasTouchSession = .init(
                start: .init(offset: Point(x: 30, y: 10), scale: 1),
                touches: [1: Point(x: 120, y: 100), 2: Point(x: 220, y: 100)]
            )
        }
        store.dispatch(.canvasTouchesEnded) { $0.canvasTouchSession = nil }
    }

    /// Two fingers preview the zoom without moving the committed layout; lifting commits it, and
    /// the view's one scale-and-offset puts every point where the preview transform would.
    @Test func aPinchPreviewsThenCommits() {
        var initial = EditorFeature.State()
        initial.canvasOffset = Point(x: 10, y: -20)
        let store = TestStore(initial: initial, behavior: EditorFeature.behavior(), environment: EditorFeature.Environment.test(newId: { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! }))
        let down = [1: Point(x: 150, y: 400), 2: Point(x: 250, y: 400)]
        let apart = [1: Point(x: 100, y: 420), 2: Point(x: 300, y: 420)]
        store.dispatch(.canvasTouchesChanged(touches(down))) {
            $0.canvasTouchSession = .init(start: .init(offset: Point(x: 10, y: -20), scale: 1), touches: down)
        }
        let session = EditorFeature.CanvasTouchSession(start: .init(offset: Point(x: 10, y: -20), scale: 1), touches: down)
        let preview = EditorFeature.canvasTransform(session, touches(apart))
        store.dispatch(.canvasTouchesChanged(touches(apart))) { $0.canvasPinchPreview = preview }
        #expect(store.state.canvasOffset == Point(x: 10, y: -20))

        // The committed layout, scaled about the view's centre and moved, lands where the preview puts it.
        let view = EditorFeature.mapState.runReader(EditorFeature.Environment.test(newId: { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! }))(store.state)
        let committed = EditorFeature.CanvasTransform(offset: store.state.canvasOffset, scale: store.state.canvasScale)
        for c in [Point(x: 450, y: 310), Point(x: 0, y: 0), Point(x: 900, y: 600)] {
            let base = screen(c, committed)
            let shown = Point(
                x: (base.x - center.x) * view.pinchScale + center.x + view.pinchOffset.x,
                y: (base.y - center.y) * view.pinchScale + center.y + view.pinchOffset.y
            )
            let target = screen(c, preview)
            #expect(abs(shown.x - target.x) < 1e-9 && abs(shown.y - target.y) < 1e-9)
        }

        store.dispatch(.canvasTouchesEnded) {
            $0.canvasTouchSession = nil
            $0.canvasPinchPreview = nil
            $0.canvasOffset = preview.offset
            $0.canvasScale = preview.scale
        }
    }
}
