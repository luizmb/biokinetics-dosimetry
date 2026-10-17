import Domain
import Foundation

// MARK: - Node geometry

/// A compartment's drawn size on the canvas at scale 1, in canvas points: wide enough for its name,
/// growing (sub-linearly) with how many links it has. The canvas draws nodes at this size, and
/// layouts are measured against it.
public func compartmentNodeSize(name: String, linkCount: Int) -> (width: Double, height: Double) {
    let textWidth = Double(name.trimmingCharacters(in: .whitespacesAndNewlines).count) * 6.5 + 20
    let baseWidth = max(72.0, textWidth)
    // sqrt-based factor so very connected nodes grow but don't become huge
    let factor = min(1.0 + sqrt(Double(max(0, linkCount - 2))) * 0.12, 1.8)
    return (width: min(max(baseWidth, 84 * factor), 200), height: max(38.0, min(48 * factor, 78)))
}

/// Every compartment's drawn size, keyed by id.
public func compartmentNodeSizes(of model: CompartmentalModel) -> [String: (width: Double, height: Double)] {
    let linkCounts = model.connections.reduce(into: [String: Int]()) { counts, connection in
        counts[connection.from, default: 0] += 1
        counts[connection.to, default: 0] += 1
    }
    return model.compartments.reduce(into: [:]) { sizes, compartment in
        sizes[compartment.id] = compartmentNodeSize(name: compartment.name, linkCount: linkCounts[compartment.id] ?? 0)
    }
}

// MARK: - Quality

/// What makes a layout hard to read, counted: compartments drawn over each other, links crossing
/// each other, and links passing under a compartment they don't belong to (reading as if they did).
public struct LayoutQuality: Equatable, Sendable, CustomStringConvertible {
    /// Pairs of compartments closer than `LayoutQuality.clearance` (overlapping, or touching).
    public var overlaps: Int
    /// Pairs of links that cross (links sharing a compartment never count).
    public var crossings: Int
    /// (link, compartment) pairs where the link passes within `clearance` of a compartment that
    /// isn't one of its ends.
    public var linksUnderCompartments: Int

    public static let clearance = 8.0

    public init(overlaps: Int, crossings: Int, linksUnderCompartments: Int) {
        self.overlaps = overlaps
        self.crossings = crossings
        self.linksUnderCompartments = linksUnderCompartments
    }

    public var description: String {
        "overlaps \(overlaps), crossings \(crossings), links under compartments \(linksUnderCompartments)"
    }
}

/// Measures `positions` (compartment centres) for `model`. A pair of opposite connections (a → b
/// and b → a) is drawn as one line, so it's measured as one link.
public func layoutQuality(of model: CompartmentalModel, positions: [String: (x: Double, y: Double)]) -> LayoutQuality {
    let sizes = compartmentNodeSizes(of: model)
    let boxes: [(id: String, box: Box)] = model.compartments.compactMap { compartment in
        guard let p = positions[compartment.id], let size = sizes[compartment.id] else { return nil }
        return (compartment.id, Box(centre: p, width: size.width, height: size.height))
    }
    let links: [(a: String, b: String, segment: Segment)] = drawnLinks(of: model).compactMap { link in
        guard let pa = positions[link.a], let pb = positions[link.b] else { return nil }
        return (link.a, link.b, Segment(from: pa, to: pb))
    }

    let overlaps = pairs(boxes.count).count { i, j in
        boxes[i].box.inflated(by: LayoutQuality.clearance / 2).intersects(boxes[j].box.inflated(by: LayoutQuality.clearance / 2))
    }
    let crossings = pairs(links.count).count { i, j in
        let (l, r) = (links[i], links[j])
        let sharesEnd = l.a == r.a || l.a == r.b || l.b == r.a || l.b == r.b
        return !sharesEnd && l.segment.crosses(r.segment)
    }
    let under = links.reduce(0) { total, link in
        total + boxes.count { node in
            node.id != link.a && node.id != link.b && link.segment.meets(node.box.inflated(by: LayoutQuality.clearance))
        }
    }
    return LayoutQuality(overlaps: overlaps, crossings: crossings, linksUnderCompartments: under)
}

/// The links as drawn: one per unordered pair of distinct compartments, in first-seen order.
func drawnLinks(of model: CompartmentalModel) -> [(a: String, b: String)] {
    model.connections.reduce(into: (seen: Set<[String]>(), links: [(a: String, b: String)]())) { acc, connection in
        guard connection.from != connection.to else { return }
        let key = [connection.from, connection.to].sorted()
        guard acc.seen.insert(key).inserted else { return }
        acc.links.append((connection.from, connection.to))
    }.links
}

private func pairs(_ count: Int) -> [(Int, Int)] {
    (0 ..< count).flatMap { i in (i + 1 ..< max(i + 1, count)).map { (i, $0) } }
}

// MARK: - Plane geometry

struct Box {
    var minX, minY, maxX, maxY: Double

    init(centre: (x: Double, y: Double), width: Double, height: Double) {
        self.init(minX: centre.x - width / 2, minY: centre.y - height / 2, maxX: centre.x + width / 2, maxY: centre.y + height / 2)
    }

    init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        (self.minX, self.minY, self.maxX, self.maxY) = (minX, minY, maxX, maxY)
    }

    func inflated(by d: Double) -> Box {
        Box(minX: minX - d, minY: minY - d, maxX: maxX + d, maxY: maxY + d)
    }

    func intersects(_ other: Box) -> Bool {
        minX < other.maxX && other.minX < maxX && minY < other.maxY && other.minY < maxY
    }

    func contains(_ p: (x: Double, y: Double)) -> Bool {
        minX <= p.x && p.x <= maxX && minY <= p.y && p.y <= maxY
    }
}

struct Segment {
    var from, to: (x: Double, y: Double)

    /// Proper crossing: each segment's ends lie strictly on opposite sides of the other.
    func crosses(_ other: Segment) -> Bool {
        let d1 = orientation(other.from, other.to, from), d2 = orientation(other.from, other.to, to)
        let d3 = orientation(from, to, other.from), d4 = orientation(from, to, other.to)
        return d1 * d2 < 0 && d3 * d4 < 0
    }

    /// Whether any part of the segment lies inside `box`.
    func meets(_ box: Box) -> Bool {
        guard !box.contains(from), !box.contains(to) else { return true }
        // Both ends outside: it meets the box only by crossing one of its sides. Cheap rejection first.
        guard max(from.x, to.x) >= box.minX, min(from.x, to.x) <= box.maxX,
              max(from.y, to.y) >= box.minY, min(from.y, to.y) <= box.maxY else { return false }
        let (a, b, c, d) = ((box.minX, box.minY), (box.maxX, box.minY), (box.maxX, box.maxY), (box.minX, box.maxY))
        return crosses(Segment(from: a, to: b)) || crosses(Segment(from: b, to: c))
            || crosses(Segment(from: c, to: d)) || crosses(Segment(from: d, to: a))
    }
}

private func orientation(_ a: (x: Double, y: Double), _ b: (x: Double, y: Double), _ c: (x: Double, y: Double)) -> Double {
    let v = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    return abs(v) < 1e-9 ? 0 : v
}
