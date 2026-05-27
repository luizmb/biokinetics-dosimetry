import XCTest
import XMLCoder
import Domain
import Parser
import Solver

/// Verifies that the four solver paths (Birchall.perTime, Birchall.semigroup,
/// RK4, RK45) agree with each other and with closed-form solutions where they
/// exist.
final class CrossSolverTests: XCTestCase {
    private let rkStep = 0.01
    private let rk45Tolerance = 1e-10
    private let crossSolverTolerance = 1e-7
    private let analyticTolerance = 1e-7

    // MARK: - Two-compartment cascade vs closed form

    func testTwoCompartmentAllSolversAgreeWithClosedForm() async {
        let k = 0.1
        let model = CompartmentalModel(
            nuclides: [],
            compartments: [
                Compartment(id: "a", nuclideId: "n0", name: "a", follow: false, intake: true, dispose: false, fraction: 1.0),
                Compartment(id: "b", nuclideId: "n0", name: "b", follow: false, intake: false, dispose: false, fraction: 0)
            ],
            connections: [CompartmentConnection(from: "a", to: "b", rate: k)]
        )
        let perTime  = await solve(model: model, step: 1, final: 50, solver: .birchall(composition: .perTime))
        let semigroup = await solve(model: model, step: 1, final: 50, solver: .birchall(composition: .semigroup))
        let rk4       = await solve(model: model, step: 1, final: 50, solver: .rungeKutta4(stepSize: rkStep))
        let rk45      = await solve(model: model, step: 1, final: 50, solver: .rungeKutta45(tolerance: rk45Tolerance))

        for t in [0, 1, 5, 10, 25, 50] {
            let aExpected = exp(-k * Double(t))
            let bExpected = 1 - aExpected
            assertAgreement(
                perTime: perTime, semigroup: semigroup, rk4: rk4, rk45: rk45,
                at: t, expecting: [aExpected, bExpected]
            )
        }
    }

    // MARK: - Bateman 3-compartment vs closed form

    func testBatemanThreeCompartmentAllSolversAgreeWithClosedForm() async {
        let k1 = 0.1
        let k2 = 0.05
        let model = CompartmentalModel(
            nuclides: [],
            compartments: [
                Compartment(id: "a", nuclideId: "n0", name: "a", follow: false, intake: true, dispose: false, fraction: 1.0),
                Compartment(id: "b", nuclideId: "n0", name: "b", follow: false, intake: false, dispose: false, fraction: 0),
                Compartment(id: "c", nuclideId: "n0", name: "c", follow: false, intake: false, dispose: false, fraction: 0)
            ],
            connections: [
                CompartmentConnection(from: "a", to: "b", rate: k1),
                CompartmentConnection(from: "b", to: "c", rate: k2)
            ]
        )
        let perTime  = await solve(model: model, step: 1, final: 100, solver: .birchall(composition: .perTime))
        let semigroup = await solve(model: model, step: 1, final: 100, solver: .birchall(composition: .semigroup))
        let rk4       = await solve(model: model, step: 1, final: 100, solver: .rungeKutta4(stepSize: rkStep))
        let rk45      = await solve(model: model, step: 1, final: 100, solver: .rungeKutta45(tolerance: rk45Tolerance))

        for t in [0, 1, 5, 10, 25, 50, 100] {
            let tD = Double(t)
            let aExpected = exp(-k1 * tD)
            let bExpected = k1 / (k2 - k1) * (exp(-k1 * tD) - exp(-k2 * tD))
            let cExpected = 1 - aExpected - bExpected
            assertAgreement(
                perTime: perTime, semigroup: semigroup, rk4: rk4, rk45: rk45,
                at: t, expecting: [aExpected, bExpected, cExpected]
            )
        }
    }

    // MARK: - Radioactive decay vs closed form

    func testRadioactiveDecayAllSolversAgreeWithClosedForm() async {
        let halfLife = 10.0
        let lambda = log(2) / halfLife
        let nuclide = Nuclide(id: "n0", name: "Test", halfLife: halfLife)
        let model = CompartmentalModel(
            nuclides: [nuclide],
            compartments: [
                Compartment(id: "a", nuclideId: nuclide.id, name: "a", follow: false, intake: true, dispose: false, fraction: 1.0)
            ],
            connections: []
        )
        let perTime  = await solve(model: model, step: 1, final: 50, solver: .birchall(composition: .perTime))
        let semigroup = await solve(model: model, step: 1, final: 50, solver: .birchall(composition: .semigroup))
        let rk4       = await solve(model: model, step: 1, final: 50, solver: .rungeKutta4(stepSize: rkStep))
        let rk45      = await solve(model: model, step: 1, final: 50, solver: .rungeKutta45(tolerance: rk45Tolerance))

        for t in [0, 1, 5, 10, 20, 50] {
            let expected = exp(-lambda * Double(t))
            assertAgreement(
                perTime: perTime, semigroup: semigroup, rk4: rk4, rk45: rk45,
                at: t, expecting: [expected]
            )
        }
    }

    // MARK: - Uranium model (real biokinetic) short-horizon agreement

    /// On the real ICRP Uranium biokinetic model, all four solvers should agree
    /// to a reasonable engineering tolerance. Tight enough to catch any wiring
    /// mistake (wrong matrix, wrong dispatch, etc.) but loose enough to not
    /// chase the last few digits when the algorithms have different truncation
    /// models (Birchall scaling-and-squaring vs RK truncation).
    func testUraniumAllSolversAgreeOnShortHorizon() async throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Uranium", withExtension: "xml"))
        let xmlData = try Data(contentsOf: url)
        let loaded = try loadIpenXml(using: XMLDecoder())(xmlData).map { $0.toCompartmentalModel() }.get()
        let halfLife = 4.5e9 * 365.0
        let model = withHalfLife(halfLife, in: loaded)
            .updatingCompartment(id: "4") { $0.with(intake: true, fraction: 1.0) }

        let perTime  = await solve(model: model, step: 1, final: 5, solver: .birchall(composition: .perTime))
        let semigroup = await solve(model: model, step: 1, final: 5, solver: .birchall(composition: .semigroup))
        let rk4       = await solve(model: model, step: 1, final: 5, solver: .rungeKutta4(stepSize: 0.001))
        let rk45      = await solve(model: model, step: 1, final: 5, solver: .rungeKutta45(tolerance: rk45Tolerance))

        XCTAssertEqual(perTime.count, semigroup.count, "perTime vs semigroup row count mismatch")
        XCTAssertEqual(perTime.count, rk4.count, "perTime vs RK4 row count mismatch")
        XCTAssertEqual(perTime.count, rk45.count, "perTime vs RK45 row count mismatch")

        for rowIndex in 0 ..< perTime.count {
            for col in 0 ..< perTime[rowIndex].count {
                XCTAssertEqual(perTime[rowIndex][col], semigroup[rowIndex][col], accuracy: 1e-12, "perTime vs semigroup t=\(rowIndex) col=\(col)")
                XCTAssertEqual(perTime[rowIndex][col], rk4[rowIndex][col], accuracy: 1e-6, "perTime vs RK4 t=\(rowIndex) col=\(col)")
                XCTAssertEqual(perTime[rowIndex][col], rk45[rowIndex][col], accuracy: 1e-6, "perTime vs RK45 t=\(rowIndex) col=\(col)")
            }
        }
    }

    // MARK: - Helpers

    /// Updates the primary (first) nuclide's half-life on a model, leaving all other fields unchanged.
    /// Compartments with `nuclideId` pointing to that nuclide inherit the updated decay constant.
    private func withHalfLife(_ halfLife: Double, in model: CompartmentalModel) -> CompartmentalModel {
        guard let first = model.nuclides.first else {
            let n = Nuclide(id: "n0", name: "Imported", halfLife: halfLife)
            return model.with(nuclides: [n])
        }
        let updated = Nuclide(id: first.id, name: first.name, halfLife: halfLife)
        return model.with(nuclides: [updated] + Array(model.nuclides.dropFirst()))
    }

    private func solve(
        model: CompartmentalModel,
        step: Double,
        final: Int,
        solver: SolverMethod
    ) async -> [[Double]] {
        await Solver.solve(
            plan: BiokineticsSimulationPlan(step: step, final: Double(final), solver: solver),
            model: model
        ).run()
    }

    /// Asserts that all four solver outputs agree with the analytic expectation
    /// at time `t`, with per-solver tolerances appropriate to each algorithm.
    private func assertAgreement(
        perTime: [[Double]],
        semigroup: [[Double]],
        rk4: [[Double]],
        rk45: [[Double]],
        at t: Int,
        expecting expected: [Double],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for (col, exp) in expected.enumerated() {
            XCTAssertEqual(perTime[t][col], exp, accuracy: analyticTolerance, "perTime vs closed-form: col \(col) at t=\(t)", file: file, line: line)
            XCTAssertEqual(semigroup[t][col], exp, accuracy: analyticTolerance, "semigroup vs closed-form: col \(col) at t=\(t)", file: file, line: line)
            XCTAssertEqual(rk4[t][col], exp, accuracy: analyticTolerance, "RK4 vs closed-form: col \(col) at t=\(t)", file: file, line: line)
            XCTAssertEqual(rk45[t][col], exp, accuracy: analyticTolerance, "RK45 vs closed-form: col \(col) at t=\(t)", file: file, line: line)
            // Cross-solver agreement: tighter for Birchall pair, loose enough for RK pair.
            XCTAssertEqual(perTime[t][col], semigroup[t][col], accuracy: 1e-12, "perTime vs semigroup: col \(col) at t=\(t)", file: file, line: line)
            XCTAssertEqual(perTime[t][col], rk4[t][col], accuracy: crossSolverTolerance, "perTime vs RK4: col \(col) at t=\(t)", file: file, line: line)
            XCTAssertEqual(perTime[t][col], rk45[t][col], accuracy: crossSolverTolerance, "perTime vs RK45: col \(col) at t=\(t)", file: file, line: line)
        }
    }
}
