import DataStructure
import Domain
import Foundation

/// A readable layout for `model`: compartment centres in canvas points, centred on the canvas
/// centre (450, 310).
///
/// Two stages:
/// 1. **Stress layout** (SMACOF): compartments land at distances proportional to how many links
///    apart they are, so hubs end up central, chains run outward and ladders lie flat.
/// 2. **Local search** on what `layoutQuality` measures: compartments are moved and swapped while a
///    score falls, with heavy penalties for overlaps and for links passing under a compartment, a
///    smaller one per crossing, and a pull towards short links. Worse moves are accepted with a
///    probability that falls over time (simulated annealing), so it doesn't stop at the first dip.
///
/// The randomness is the `Gen`: it draws the start positions and the list of candidate moves, and
/// the rest is a pure function of those. Run it with a seeded `SplitMix64` for a reproducible layout.
public func tidyLayout<R: RandomNumberGenerator & Sendable>(
    of model: CompartmentalModel,
    attempts: Int = 6
) -> Gen<R, [String: (x: Double, y: Double)]> {
    let ids = model.compartments.map(\.id)
    let index = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
    let allSizes = compartmentNodeSizes(of: model)
    let sizes = ids.map { allSizes[$0] ?? (width: 84, height: 48) }
    let links = drawnLinks(of: model).compactMap { link in
        index[link.a].flatMap { a in index[link.b].map { b in (a, b) } }
    }
    let n = ids.count
    let hubs = hubIndices(count: n, links: links)
    guard n > 1 else { return .pure(centred(Dictionary(uniqueKeysWithValues: ids.map { ($0, (x: 0.0, y: 0.0)) }))) }
    let start = Gen<R, (Double, Double)>.zip(.double(in: 0 ... 600), .double(in: 0 ... 600))
        .map { (x: $0.0, y: $0.1) }
        .array(ofCount: n)
        .array(ofCount: max(1, attempts))
    let moves = (LayoutMove.generator(count: n) as Gen<R, LayoutMove>).array(ofCount: LayoutSearch.steps(for: n))
    return Gen<R, ([[(x: Double, y: Double)]], [LayoutMove])>.zip(start, moves).map { starts, moves in
        // Where a run starts decides much of where it ends (the same model ends with 2 or 31
        // crossings), so each start gets four runs and the best of all is kept, by what
        // `layoutQuality` counts (the score only steers each run):
        // - hub links as two hops keeps compartments between the hubs they link (a decay chain's
        //   bands); leaving them out lets a single hub's satellites (a respiratory tract's ladder)
        //   take their own shape;
        // - a hub's link crossing an ordinary one priced low lets several hubs reach across the
        //   chains between them; priced as any crossing, a single hub's links route clear.
        let runs = starts.flatMap { start in [2, nil].map { (start, $0) } }.flatMap { start, hubHops in
            [Penalty.crossing, Penalty.hubCrossing].map { hubCrossing in
                let initial = stressLayout(from: start, links: links, hubs: hubs, hubHops: hubHops, sizes: sizes)
                return LayoutSearch(positions: initial, sizes: sizes, links: links, hubs: hubs, hubCrossing: hubCrossing)
                    .anneal(moves)
                    .positions
            }
        }
        let best = runs
            .map { positions in (positions, layoutQuality(of: model, positions: Dictionary(uniqueKeysWithValues: zip(ids, positions)))) }
            .min { lhs, rhs in lhs.1.rank.lexicographicallyPrecedes(rhs.1.rank) }
        return centred(Dictionary(uniqueKeysWithValues: zip(ids, best?.0 ?? starts.first ?? [])))
    }
}

extension LayoutQuality {
    /// Overlaps and links under compartments first (they make a diagram wrong), then crossings.
    fileprivate var rank: [Int] { [overlaps + linksUnderCompartments, crossings] }
}

/// One candidate step of the search, drawn up front: what to try, and the uniform draw that decides
/// whether a worse result is kept.
struct LayoutMove: Sendable {
    enum Kind: Sendable {
        case swap(Int, Int)
        /// Moves one compartment by (dx, dy) × the current reach, dx and dy in -1 ... 1.
        case shift(Int, dx: Double, dy: Double)
        /// Moves one compartment to the mean position of its neighbours, offset by (dx, dy) × the
        /// current reach: the classic move for untangling crossings.
        case centre(Int, dx: Double, dy: Double)
    }

    let kind: Kind
    let acceptance: Double

    static func generator<R: RandomNumberGenerator & Sendable>(count n: Int) -> Gen<R, LayoutMove> {
        Gen<R, (Double, Int, Int, Double, Double, Double)>.zip(
            .double(in: 0 ... 1), .int(in: 0 ... n - 1), .int(in: 0 ... n - 1),
            .double(in: -1 ... 1), .double(in: -1 ... 1), .double(in: 0 ... 1)
        )
        .map { pick, a, b, dx, dy, acceptance in
            let kind: Kind = pick < 0.2 ? .swap(a, b) : pick < 0.35 ? .centre(a, dx: dx, dy: dy) : .shift(a, dx: dx, dy: dy)
            return LayoutMove(kind: kind, acceptance: acceptance)
        }
    }
}

/// Compartments with far more links than the rest (plasma, blood): at least 8 links and at least
/// four times the median. Everything is one or two links from a hub, so its links say little about
/// where things belong: the layout follows the other links, and a hub's links may run long.
func hubIndices(count n: Int, links: [(Int, Int)]) -> Set<Int> {
    let degrees = links.reduce(into: [Int](repeating: 0, count: n)) { degrees, link in
        degrees[link.0] += 1
        degrees[link.1] += 1
    }
    let median = degrees.sorted()[n / 2]
    return Set(degrees.indices.filter { degrees[$0] >= max(8, 4 * median) })
}

// MARK: - Stress

/// SMACOF (stress majorization) by localized updates, weights 1/d²: the standard way to lay a graph
/// out by its graph distances. A hub's link counts as `hubHops` hops, or not at all when nil, so the
/// other links shape the layout.
private func stressLayout(
    from start: [(x: Double, y: Double)],
    links: [(Int, Int)],
    hubs: Set<Int>,
    hubHops: Int?,
    sizes: [(width: Double, height: Double)]
) -> [(x: Double, y: Double)] {
    let n = start.count
    let neighbours = links.reduce(into: [[(node: Int, hops: Int)]](repeating: [], count: n)) { adjacency, link in
        let isHubLink = hubs.contains(link.0) || hubs.contains(link.1)
        guard let hops = isHubLink ? hubHops : 1 else { return }
        adjacency[link.0].append((link.1, hops))
        adjacency[link.1].append((link.0, hops))
    }
    let hops = (0 ..< n).map { shortestDistances(from: $0, neighbours: neighbours) }
    let farthest = hops.flatMap { $0.compactMap { $0 } }.max() ?? 1
    // One hop is wide enough for the two compartments' halves and a gap: wide names sit further apart.
    let unit = 150.0
    let ideal: [[Double]] = (0 ..< n).map { i in
        (0 ..< n).map { j in
            let hop = Double(hops[i][j] ?? farthest + 1)
            return hop * unit + (sizes[i].width + sizes[j].width) / 4
        }
    }
    var positions = start
    for _ in 0 ..< 300 {
        for i in 0 ..< n {
            var (sumX, sumY, sumW) = (0.0, 0.0, 0.0)
            for j in 0 ..< n where j != i {
                let dx = positions[i].x - positions[j].x, dy = positions[i].y - positions[j].y
                let distance = max(sqrt(dx * dx + dy * dy), 1e-6)
                let weight = 1 / (ideal[i][j] * ideal[i][j])
                sumX += weight * (positions[j].x + ideal[i][j] * dx / distance)
                sumY += weight * (positions[j].y + ideal[i][j] * dy / distance)
                sumW += weight
            }
            if sumW > 0 { positions[i] = (sumX / sumW, sumY / sumW) }
        }
    }
    return positions
}

/// Dijkstra over small integer weights (1 or 2 hops): plain O(n²), the graphs are small.
private func shortestDistances(from source: Int, neighbours: [[(node: Int, hops: Int)]]) -> [Int?] {
    var distances = [Int?](repeating: nil, count: neighbours.count)
    var done = [Bool](repeating: false, count: neighbours.count)
    distances[source] = 0
    while let node = distances.indices.filter({ !done[$0] && distances[$0] != nil }).min(by: { (distances[$0] ?? 0) < (distances[$1] ?? 0) }) {
        done[node] = true
        let base = distances[node] ?? 0
        for (next, hops) in neighbours[node] where distances[next].map({ base + hops < $0 }) ?? true {
            distances[next] = base + hops
        }
    }
    return distances
}

// MARK: - Local search

/// Score terms. Overlaps and links under compartments are what make a diagram wrong, so they cost
/// far more than a crossing, which only makes it harder to follow; link length keeps it compact.
private enum Penalty {
    static let overlap = 100_000.0
    static let linkUnderCompartment = 20_000.0
    static let crossing = 2_000.0
    /// A hub's link crossing an ordinary link, in the runs that price it low: the hub's link visibly
    /// runs to the hub, so it costs less to read. Two hubs' links crossing costs the full `crossing`.
    static let hubCrossing = 300.0
    static let crowding = 300.0
    /// Gap kept between compartments (penalised as crowding below it).
    static let gap = 28.0
    /// Distance a link keeps from compartments it doesn't belong to.
    static let linkClearance = 14.0
}

private struct LayoutSearch {
    var positions: [(x: Double, y: Double)]
    let sizes: [(width: Double, height: Double)]
    let links: [(Int, Int)]
    /// Links incident to each compartment.
    let incident: [[Int]]
    /// How much each link's length counts: a hub's links count a fifth.
    let lengthWeight: [Double]
    let isHubLink: [Bool]
    /// What a hub's link crossing an ordinary link costs.
    let hubCrossing: Double

    init(
        positions: [(x: Double, y: Double)],
        sizes: [(width: Double, height: Double)],
        links: [(Int, Int)],
        hubs: Set<Int>,
        hubCrossing: Double
    ) {
        self.hubCrossing = hubCrossing
        self.positions = positions
        self.sizes = sizes
        self.links = links
        self.isHubLink = links.map { hubs.contains($0.0) || hubs.contains($0.1) }
        self.lengthWeight = isHubLink.map { $0 ? 0.2 : 1 }
        self.incident = links.enumerated().reduce(into: [[Int]](repeating: [], count: positions.count)) { acc, pair in
            acc[pair.element.0].append(pair.offset)
            acc[pair.element.1].append(pair.offset)
        }
    }

    static func steps(for n: Int) -> Int { 3_000 * n }

    /// Tries `moves` in order, keeping each one that lowers the score, and a worse one when its
    /// acceptance draw falls under exp(-increase / temperature). Returns the best layout seen.
    func anneal(_ moves: [LayoutMove]) -> (positions: [(x: Double, y: Double)], score: Double) {
        var search = self
        let n = positions.count
        let (hot, cold) = (4_000.0, 1.0)
        var best = (positions: positions, score: search.score(of: Array(0 ..< n)))
        var current = best.score
        for (step, move) in moves.enumerated() {
            let progress = Double(step) / Double(max(moves.count, 1))
            let temperature = hot * pow(cold / hot, progress)
            let reach = 260 * (1 - progress) + 8
            let moved: [Int]
            switch move.kind {
            case let .swap(a, b) where a != b: moved = [a, b]
            case let .shift(a, _, _), let .centre(a, _, _): moved = [a]
            case .swap: continue
            }
            let before = search.score(of: moved)
            let saved = moved.map { search.positions[$0] }
            switch move.kind {
            case let .swap(a, b): search.positions.swapAt(a, b)
            case let .shift(a, dx, dy):
                search.positions[a] = ((search.positions[a].x + dx * reach).rounded(), (search.positions[a].y + dy * reach).rounded())
            case let .centre(a, dx, dy):
                let mean = search.neighbourMean(of: a)
                search.positions[a] = ((mean.x + dx * reach / 2).rounded(), (mean.y + dy * reach / 2).rounded())
            }
            let delta = search.score(of: moved) - before
            if delta <= 0 || move.acceptance < exp(-delta / temperature) {
                current += delta
                if current < best.score { best = (search.positions, current) }
            } else {
                for (node, position) in zip(moved, saved) { search.positions[node] = position }
            }
        }
        return best
    }

    /// Every score term involving at least one compartment of `moved`, each pair counted once.
    /// Moving those compartments changes exactly these terms, so the change in this sum is the
    /// change in the whole score.
    func score(of moved: [Int]) -> Double {
        let movedLinks = Set(moved.flatMap { incident[$0] })
        var total = 0.0
        for a in moved {
            for b in positions.indices where b != a && !(moved.contains(b) && b < a) {
                total += nodePairPenalty(a, b)
            }
        }
        for l in movedLinks {
            let segment = self.segment(l)
            total += segment.length * lengthWeight[l]
            for m in links.indices where m != l && !(movedLinks.contains(m) && m < l) && !sharesEnd(l, m) {
                if segment.crosses(self.segment(m)) { total += isHubLink[l] != isHubLink[m] ? hubCrossing : Penalty.crossing }
            }
            for node in positions.indices where node != links[l].0 && node != links[l].1 {
                if segment.meets(box(node, inflatedBy: Penalty.linkClearance)) { total += Penalty.linkUnderCompartment }
            }
        }
        for l in links.indices where !movedLinks.contains(l) {
            let segment = self.segment(l)
            for node in moved where node != links[l].0 && node != links[l].1 {
                if segment.meets(box(node, inflatedBy: Penalty.linkClearance)) { total += Penalty.linkUnderCompartment }
            }
        }
        return total
    }

    func neighbourMean(of node: Int) -> (x: Double, y: Double) {
        let ends = incident[node].map { links[$0].0 == node ? links[$0].1 : links[$0].0 }
        guard !ends.isEmpty else { return positions[node] }
        let sum = ends.reduce((x: 0.0, y: 0.0)) { ($0.x + positions[$1].x, $0.y + positions[$1].y) }
        return (sum.x / Double(ends.count), sum.y / Double(ends.count))
    }

    private func nodePairPenalty(_ a: Int, _ b: Int) -> Double {
        if box(a, inflatedBy: LayoutQuality.clearance / 2).intersects(box(b, inflatedBy: LayoutQuality.clearance / 2)) {
            return Penalty.overlap
        }
        return box(a, inflatedBy: Penalty.gap / 2).intersects(box(b, inflatedBy: Penalty.gap / 2)) ? Penalty.crowding : 0
    }

    private func sharesEnd(_ l: Int, _ m: Int) -> Bool {
        let (a, b) = links[l], (c, d) = links[m]
        return a == c || a == d || b == c || b == d
    }

    private func segment(_ l: Int) -> Segment {
        Segment(from: positions[links[l].0], to: positions[links[l].1])
    }

    private func box(_ node: Int, inflatedBy d: Double) -> Box {
        Box(centre: positions[node], width: sizes[node].width, height: sizes[node].height).inflated(by: d)
    }
}

extension Segment {
    var length: Double {
        let dx = to.x - from.x, dy = to.y - from.y
        return sqrt(dx * dx + dy * dy)
    }
}

/// Moves the layout so its bounding box is centred on the canvas centre.
private func centred(_ positions: [String: (x: Double, y: Double)]) -> [String: (x: Double, y: Double)] {
    let xs = positions.values.map(\.x), ys = positions.values.map(\.y)
    guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return positions }
    let (dx, dy) = (450 - (minX + maxX) / 2, 310 - (minY + maxY) / 2)
    return positions.mapValues { (x: ($0.x + dx).rounded(), y: ($0.y + dy).rounded()) }
}
