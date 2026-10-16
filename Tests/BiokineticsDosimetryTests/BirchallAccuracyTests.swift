import Domain
import Foundation
import Parser
import Solver
import Testing
import XMLCoder

/// Accuracy against the true trajectory, not agreement with another implementation.
///
/// `UraniumGoldenTests` checks the Swift port against the C# original; both run the same algorithm in
/// `Double`, so they agree to 1e-12 while both sit ~1e-11 from the exact answer. This suite holds the
/// error itself: `uranium_birchall_float80.json` is the Uranium trajectory computed in `Float80`
/// (64-bit significand, ~1e-19 unit roundoff) as `e^A` once, iterated — a route that agrees with
/// `(e^A)^1000` by repeated squaring to 6e-19. Measured on 2026-10-16: perTime 1.4e-11, semigroup
/// 4.1e-12 (normwise, worst day). The bound leaves headroom for summation-order changes (BLAS,
/// another platform) and fails on anything that actually costs precision: rounding the exponential
/// to `Float` gives 2.9e-7 and fails. (Cutting the Taylor series short does not move it on this
/// model: the scaled matrix is tiny, and truncation only touches the fast modes (rates up to
/// ~35/day), which have decayed away within days.)
@Suite("Birchall accuracy (Float80 reference)")
struct BirchallAccuracyTests {
    struct Reference: Codable {
        let step: Double
        let final: Double
        let times: [Int]
        let rows: [[Double]]
    }

    static let bound = 1e-10

    @Test(arguments: [BirchallComposition.perTime, .semigroup])
    func birchallStaysWithinBoundOfTheExactTrajectory(composition: BirchallComposition) async throws {
        let url = try #require(Bundle.module.url(forResource: "uranium_birchall_float80", withExtension: "json"))
        let reference = try JSONDecoder().decode(Reference.self, from: Data(contentsOf: url))
        let model = try uraniumModel()
        let plan = BiokineticsSimulationPlan(step: reference.step, final: reference.final, solver: .birchall(composition: composition))
        let rows = try await solve(plan: plan, model: model).run().get()

        for (time, expected) in zip(reference.times, reference.rows) {
            let scale = expected.map(abs).max() ?? 0
            let error = zip(rows[time], expected).map { abs($0 - $1) }.max() ?? 0
            #expect(error <= Self.bound * max(scale, 1), "t=\(time): error \(error), row scale \(scale)")
        }
    }

    #if arch(x86_64) && !os(Windows)
    /// Regenerates the fixture (x86_64 only: `Float80` doesn't exist on arm64).
    /// `RECORD_FLOAT80_REFERENCE=1 swift test --filter BirchallAccuracyTests`
    @Test(.enabled(if: ProcessInfo.processInfo.environment["RECORD_FLOAT80_REFERENCE"] != nil))
    func recordFloat80Reference() throws {
        let system = try uraniumModel().linearSystem()
        let (step, final) = (1.0, 1000)
        let n = system.matrix.rows
        let propagator = Float80Matrix(system.matrix.storage.map { Float80($0) * Float80(step) }, size: n).exponential()
        let trajectory = (0 ... final).reduce(into: [system.initialConditions.map { Float80($0) }]) { rows, _ in
            rows.append(propagator.apply(to: rows[rows.count - 1]))
        }
        let times = Array(stride(from: 0, through: final, by: 10)) + [final + 1]
        let reference = Reference(step: step, final: Double(final), times: times, rows: times.map { trajectory[$0].map { Double($0) } })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let destination = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/uranium_birchall_float80.json")
        try encoder.encode(reference).write(to: destination)
    }
    #endif
}

func uraniumModel() throws -> CompartmentalModel {
    let url = try #require(Bundle.module.url(forResource: "Uranium", withExtension: "xml"))
    let loaded = try loadIpenXml(using: XMLDecoder())(Data(contentsOf: url)).map { $0.toCompartmentalModel() }.get()
    let halfLife = 1_642_500_000_000.0
    let nuclide = loaded.nuclides.first.map { Nuclide(id: $0.id, name: $0.name, halfLife: halfLife) }
        ?? Nuclide(id: "n0", name: "Imported", halfLife: halfLife)
    return loaded.with(nuclides: [nuclide] + Array(loaded.nuclides.dropFirst()))
        .updatingCompartment(id: "4") { $0.with(intake: true, fraction: 1.0) }
}

#if arch(x86_64) && !os(Windows)
/// Just enough dense `Float80` linear algebra for the reference: row-major, square.
private struct Float80Matrix {
    var entries: [Float80]
    let size: Int

    init(_ entries: [Float80], size: Int) {
        self.entries = entries
        self.size = size
    }

    static func identity(_ size: Int) -> Float80Matrix {
        Float80Matrix((0 ..< size * size).map { $0 / size == $0 % size ? 1 : 0 }, size: size)
    }

    static func * (lhs: Float80Matrix, rhs: Float80Matrix) -> Float80Matrix {
        let n = lhs.size
        var product = [Float80](repeating: 0, count: n * n)
        for i in 0 ..< n {
            for k in 0 ..< n where lhs.entries[i * n + k] != 0 {
                for j in 0 ..< n {
                    product[i * n + j] += lhs.entries[i * n + k] * rhs.entries[k * n + j]
                }
            }
        }
        return Float80Matrix(product, size: n)
    }

    func apply(to vector: [Float80]) -> [Float80] {
        (0 ..< size).map { i in (0 ..< size).reduce(Float80(0)) { $0 + entries[i * size + $1] * vector[$1] } }
    }

    /// Scaling and squaring with a much smaller scaled norm (2^-8) and a much tighter series cut (1e-30)
    /// than Birchall's `Double` defaults.
    func exponential() -> Float80Matrix {
        let norm = (0 ..< size).map { i in (0 ..< size).reduce(Float80(0)) { $0 + abs(entries[i * size + $1]) } }.max() ?? 0
        let k = (0...).first { norm / Float80(sign: .plus, exponent: $0, significand: 1) <= 1 / 256 } ?? 0
        let scaled = Float80Matrix(entries.map { $0 / Float80(sign: .plus, exponent: k, significand: 1) }, size: size)
        let series = (1 ... 200).reduce(into: (sum: Self.identity(size), term: Self.identity(size), done: false)) { acc, r in
            guard !acc.done else { return }
            acc.term = acc.term * scaled
            acc.term.entries = acc.term.entries.map { $0 / Float80(r) }
            acc.sum.entries = zip(acc.sum.entries, acc.term.entries).map(+)
            acc.done = (acc.term.entries.map(abs).max() ?? 0) < 1e-30
        }
        return (0 ..< k).reduce(series.sum) { m, _ in m * m }
    }
}
#endif
