import XCTest
import XMLCoder
import Domain
import Parser
import Solver

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
        let loaded = try loadIpenXml(using: XMLDecoder())(xmlData).map { $0.toCompartmentalModel() }.get()
        let halfLife = 1_642_500_000_000.0
        let nuclide = loaded.nuclides.first.map { Nuclide(id: $0.id, name: $0.name, halfLife: halfLife) }
            ?? Nuclide(id: "n0", name: "Imported", halfLife: halfLife)
        let modelWithHL = loaded.with(nuclides: [nuclide] + Array(loaded.nuclides.dropFirst()))
        let model = modelWithHL.updatingCompartment(id: "4") { $0.with(intake: true, fraction: 1.0) }

        let solvers: [(name: String, method: SolverMethod)] = [
            ("Birchall (perTime, concurrent) ", .birchall(composition: .perTime)),
            ("Birchall (semigroup)           ", .birchall(composition: .semigroup)),
            ("RK4      (stepSize=0.01)       ", .rungeKutta4(stepSize: 0.01)),
            ("RK45     (tolerance=1e-10)     ", .rungeKutta45(tolerance: 1e-10))
        ]

        for solver in solvers {
            let calculator = BiokineticsSimulationPlan(step: 1, final: 1000, solver: solver.method)
            let start = Date()
            _ = await solve(plan: calculator, model: model).run()
            let elapsed = Date().timeIntervalSince(start)
            print(String(format: "%@  %8.2f s", solver.name, elapsed))
        }
    }
}
