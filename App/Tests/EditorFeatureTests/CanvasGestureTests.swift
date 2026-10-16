import EditorFeature
import Foundation
import SwiftRex
import SwiftRexTesting
import Testing

/// Pan and pinch: the view reports raw finger values, the reducer turns them into the transform.
@Suite("Canvas pan and pinch")
@MainActor
struct CanvasGestureTests {
    private typealias Point = EditorFeature.CanvasPoint

    private func gesture(
        translation: Point = Point(x: 0, y: 0), magnification: Double = 1,
        anchor: Point? = nil, finger: Point = Point(x: 0, y: 0)
    ) -> EditorFeature.CanvasGesture {
        EditorFeature.CanvasGesture(
            translation: translation, magnification: magnification, anchor: anchor,
            fingerOffsetFromAnchor: finger, viewCenter: Point(x: 200, y: 400)
        )
    }

    /// Screen point of canvas point `c` under `t` (the canvas view's mapping, centre 200 × 400).
    private func screen(_ c: Point, _ t: EditorFeature.CanvasTransform) -> Point {
        Point(x: (c.x - 450) * t.scale + 200 + t.offset.x, y: (c.y - 310) * t.scale + 400 + t.offset.y)
    }

    private func canvas(_ p: Point, _ t: EditorFeature.CanvasTransform) -> Point {
        Point(x: (p.x - 200 - t.offset.x) / t.scale + 450, y: (p.y - 400 - t.offset.y) / t.scale + 310)
    }

    @Test func aPanMovesByTheTranslation() {
        let start = EditorFeature.CanvasTransform(offset: Point(x: 10, y: -5), scale: 1.5)
        let moved = EditorFeature.canvasTransform(from: start, by: gesture(translation: Point(x: 30, y: 12)))
        #expect(moved == EditorFeature.CanvasTransform(offset: Point(x: 40, y: 7), scale: 1.5))
    }

    /// The canvas point under the fingers when the pinch started is still under them.
    @Test func aPinchKeepsItsAnchorInPlace() {
        let start = EditorFeature.CanvasTransform(offset: Point(x: 25, y: -40), scale: 1.2)
        let anchor = Point(x: 310, y: 250)
        let underFingers = canvas(anchor, start)
        let zoomed = EditorFeature.canvasTransform(from: start, by: gesture(magnification: 2, anchor: anchor))
        #expect(zoomed.scale == 2.4)
        let after = screen(underFingers, zoomed)
        #expect(abs(after.x - anchor.x) < 1e-9 && abs(after.y - anchor.y) < 1e-9)
    }

    /// Fingers spreading symmetrically around the anchor don't pan: the tracked finger's own spread
    /// is taken off its translation.
    @Test func aSymmetricPinchDoesNotPan() {
        let start = EditorFeature.CanvasTransform(offset: Point(x: 0, y: 0), scale: 1)
        let anchor = Point(x: 200, y: 400)
        // Finger started 50 pt left of the anchor; at 2× it is 100 pt left: moved -50.
        let pinched = EditorFeature.canvasTransform(
            from: start, by: gesture(translation: Point(x: -50, y: 0), magnification: 2, anchor: anchor, finger: Point(x: -50, y: 0))
        )
        #expect(pinched == EditorFeature.CanvasTransform(offset: Point(x: 0, y: 0), scale: 2))
    }

    /// The reducer records where the gesture started from its own state and applies each update to
    /// that, so updates don't compound; the end clears it.
    @Test func theReducerAppliesUpdatesToTheGesturesStart() {
        var initial = EditorFeature.State()
        initial.canvasOffset = Point(x: 10, y: 10)
        let store = TestStore(initial: initial, behavior: EditorFeature.behavior(), environment: .init(newId: { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! }))
        let start = EditorFeature.CanvasTransform(offset: Point(x: 10, y: 10), scale: 1)
        store.dispatch(.canvasGestureChanged(gesture(translation: Point(x: 5, y: 0)))) {
            $0.canvasGestureStart = start
            $0.canvasOffset = Point(x: 15, y: 10)
        }
        store.dispatch(.canvasGestureChanged(gesture(translation: Point(x: 20, y: 0)))) {
            $0.canvasOffset = Point(x: 30, y: 10)
        }
        store.dispatch(.canvasGestureEnded) { $0.canvasGestureStart = nil }
    }
}
