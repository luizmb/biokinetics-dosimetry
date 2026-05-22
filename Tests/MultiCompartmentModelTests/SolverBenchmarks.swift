import XCTest
import XMLCoder
@testable import MultiCompartmentModel

/// One-shot timing of all four solver paths on the Uranium golden setup
/// (step=1 day, final=1000 days). Gated by `RUN_BENCH=1`; not part of the
/// default test pass because each solver is slow on this horizon.
final class SolverBenchmarks: XCTestCase {
    func testUraniumSolverTimings() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_BENCH"] != nil,
            "Set RUN_BENCH=1 to run the Uranium solver timings."
        )

        let xmlURL = try XCTUnwrap(Bundle.module.url(forResource: "Uranium", withExtension: "xml"))
        let xmlData = try Data(contentsOf: xmlURL)
        let loaded = try loadCompartmentalModel(using: XMLDecoder())(xmlData).get()
        let model = loaded.updatingCompartment(id: "4") { $0.with(intake: true, fraction: 1.0) }
        let halfLife = 1_642_500_000_000.0
        let step = 1
        let final = 1000

        let solvers: [(name: String, method: SolverMethod)] = [
            ("Birchall (perTime, concurrent) ", .birchall(composition: .perTime)),
            ("Birchall (semigroup)           ", .birchall(composition: .semigroup)),
            ("RK4      (stepSize=0.01)       ", .rungeKutta4(stepSize: 0.01)),
            ("RK45     (tolerance=1e-10)     ", .rungeKutta45(tolerance: 1e-10))
        ]

        for solver in solvers {
            let calculator = InternalDosimetryCalculator(
                step: step,
                halfLife: halfLife,
                final: final,
                solver: solver.method
            )
            let start = Date()
            _ = await calculator.calculate(model: model).run()
            let elapsed = Date().timeIntervalSince(start)
            print(String(format: "%@  %8.2f s", solver.name, elapsed))
        }
    }
}
