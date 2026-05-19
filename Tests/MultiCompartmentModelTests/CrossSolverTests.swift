import XCTest
import XMLCoder
@testable import MultiCompartmentModel

/// Verifies that the RK4 solver path agrees with the Birchall analytical path,
/// and with closed-form solutions where they exist.
final class CrossSolverTests: XCTestCase {
    private let rkStep = 0.01
    private let crossSolverTolerance = 1e-7
    private let analyticTolerance = 1e-7

    func testTwoCompartmentBothSolversAgreeWithClosedForm() {
        let k = 0.1
        let model = CompartmentalModel(
            compartments: [
                Compartment(id: "a", name: "a", follow: false, intake: true, dispose: false, fraction: 1.0),
                Compartment(id: "b", name: "b", follow: false, intake: false, dispose: false, fraction: 0)
            ],
            connections: [CompartmentConnection(from: "a", to: "b", rate: k)]
        )
        let birchall = solve(model: model, halfLife: 0, step: 1, final: 50, solver: .birchall)
        let rk = solve(model: model, halfLife: 0, step: 1, final: 50, solver: .rungeKutta4(stepSize: rkStep))

        for t in [0, 1, 5, 10, 25, 50] {
            let aExpected = exp(-k * Double(t))
            let bExpected = 1 - aExpected
            XCTAssertEqual(birchall[t][0], rk[t][0], accuracy: crossSolverTolerance, "Birchall vs RK4: a at t=\(t)")
            XCTAssertEqual(birchall[t][1], rk[t][1], accuracy: crossSolverTolerance, "Birchall vs RK4: b at t=\(t)")
            XCTAssertEqual(rk[t][0], aExpected, accuracy: analyticTolerance, "RK4 vs closed-form: a at t=\(t)")
            XCTAssertEqual(rk[t][1], bExpected, accuracy: analyticTolerance, "RK4 vs closed-form: b at t=\(t)")
        }
    }

    func testBatemanThreeCompartmentBothSolversAgreeWithClosedForm() {
        let k1 = 0.1
        let k2 = 0.05
        let model = CompartmentalModel(
            compartments: [
                Compartment(id: "a", name: "a", follow: false, intake: true, dispose: false, fraction: 1.0),
                Compartment(id: "b", name: "b", follow: false, intake: false, dispose: false, fraction: 0),
                Compartment(id: "c", name: "c", follow: false, intake: false, dispose: false, fraction: 0)
            ],
            connections: [
                CompartmentConnection(from: "a", to: "b", rate: k1),
                CompartmentConnection(from: "b", to: "c", rate: k2)
            ]
        )
        let birchall = solve(model: model, halfLife: 0, step: 1, final: 100, solver: .birchall)
        let rk = solve(model: model, halfLife: 0, step: 1, final: 100, solver: .rungeKutta4(stepSize: rkStep))

        for t in [0, 1, 5, 10, 25, 50, 100] {
            let tD = Double(t)
            let aExpected = exp(-k1 * tD)
            let bExpected = k1 / (k2 - k1) * (exp(-k1 * tD) - exp(-k2 * tD))
            let cExpected = 1 - aExpected - bExpected
            XCTAssertEqual(birchall[t][0], rk[t][0], accuracy: crossSolverTolerance, "Birchall vs RK4: a at t=\(t)")
            XCTAssertEqual(birchall[t][1], rk[t][1], accuracy: crossSolverTolerance, "Birchall vs RK4: b at t=\(t)")
            XCTAssertEqual(birchall[t][2], rk[t][2], accuracy: crossSolverTolerance, "Birchall vs RK4: c at t=\(t)")
            XCTAssertEqual(rk[t][0], aExpected, accuracy: analyticTolerance, "RK4: a at t=\(t)")
            XCTAssertEqual(rk[t][1], bExpected, accuracy: analyticTolerance, "RK4: b at t=\(t)")
            XCTAssertEqual(rk[t][2], cExpected, accuracy: analyticTolerance, "RK4: c at t=\(t)")
        }
    }

    func testRadioactiveDecayBothSolversAgreeWithClosedForm() {
        let halfLife = 10.0
        let lambda = log(2) / halfLife
        let model = CompartmentalModel(
            compartments: [
                Compartment(id: "a", name: "a", follow: false, intake: true, dispose: false, fraction: 1.0)
            ],
            connections: []
        )
        let birchall = solve(model: model, halfLife: halfLife, step: 1, final: 50, solver: .birchall)
        let rk = solve(model: model, halfLife: halfLife, step: 1, final: 50, solver: .rungeKutta4(stepSize: rkStep))

        for t in [0, 1, 5, 10, 20, 50] {
            let expected = exp(-lambda * Double(t))
            XCTAssertEqual(birchall[t][0], rk[t][0], accuracy: crossSolverTolerance, "Birchall vs RK4 at t=\(t)")
            XCTAssertEqual(rk[t][0], expected, accuracy: analyticTolerance, "RK4 vs closed-form at t=\(t)")
        }
    }

    /// On the real ICRP Uranium biokinetic model, the two solvers should agree to a
    /// reasonable engineering tolerance — Birchall is essentially exact, RK4 carries
    /// O(h⁴) truncation. Tight enough to catch any wiring mistake (wrong matrix,
    /// wrong dispatch, etc.) but loose enough to not chase the last few digits.
    func testUraniumBothSolversAgreeOnShortHorizon() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Uranium", withExtension: "xml"))
        let xmlData = try Data(contentsOf: url)
        let loaded = try loadCompartmentalModel(using: XMLDecoder())(xmlData).get()
        let model = loaded.updatingCompartment(id: "4") { $0.with(intake: true, fraction: 1.0) }
        let halfLife = 4.5e9 * 365.0

        let birchall = solve(model: model, halfLife: halfLife, step: 1, final: 5, solver: .birchall)
        let rk = solve(model: model, halfLife: halfLife, step: 1, final: 5, solver: .rungeKutta4(stepSize: 0.001))

        XCTAssertEqual(birchall.count, rk.count, "row count mismatch")
        for (rowIndex, (b, r)) in zip(birchall, rk).enumerated() {
            for (col, (bValue, rValue)) in zip(b, r).enumerated() {
                XCTAssertEqual(
                    bValue, rValue, accuracy: 1e-6,
                    "t=\(rowIndex) compartment \(col)"
                )
            }
        }
    }

    private func solve(
        model: CompartmentalModel,
        halfLife: Double,
        step: Int,
        final: Int,
        solver: SolverMethod
    ) -> [[Double]] {
        InternalDosimetryCalculator(step: step, halfLife: halfLife, final: final, solver: solver)
            .calculate(model: model)
    }
}
