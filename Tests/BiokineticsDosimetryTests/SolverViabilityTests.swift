import Domain
import Foundation
import Solver
import Testing

/// Every method the calculator offers has to be worth picking: close to the exact trajectory with
/// its default settings, or a clear failure when the settings can't work, never numbers for days it
/// didn't integrate or that grew without bound.
@Suite("Solver viability (Float80 reference)")
struct SolverViabilityTests {
    private func reference() throws -> BirchallAccuracyTests.Reference {
        let url = try #require(Bundle.module.url(forResource: "uranium_birchall_float80", withExtension: "json"))
        return try JSONDecoder().decode(BirchallAccuracyTests.Reference.self, from: Data(contentsOf: url))
    }

    private func worstError(_ solver: SolverMethod) async throws -> Double {
        let reference = try reference()
        let plan = BiokineticsSimulationPlan(step: reference.step, final: reference.final, solver: solver)
        let rows = try await solve(plan: plan, model: uraniumModel()).run().get()
        return zip(reference.times, reference.rows)
            .map { time, expected in zip(rows[time], expected).map { abs($0 - $1) }.max() ?? 0 }
            .max() ?? 0
    }

    /// Measured on 2026-10-16: 1.2e-12 at 1e-14 and 5.8e-12 at 1e-13, ~12.5 steps a day. RK45 is
    /// stability-limited on Uranium (fastest rate 35/day), so a tight tolerance costs ~10% more steps.
    @Test func rk45AtItsDefaultToleranceIsAsCloseAsBirchall() async throws {
        #expect(try await worstError(.rungeKutta45(tolerance: 1e-13, budget: .automatic)) < 1e-10)
    }

    /// RK4's own truncation error at h = 0.01 d, through the linear propagator.
    @Test func rk4AtItsDefaultStepIsAccurate() async throws {
        #expect(try await worstError(.rungeKutta4(stepSize: 0.01)) < 1e-8)
    }

    /// h = 1 d on rates of 35/day: RK4 would reach 1e146 by day 30. The solver refuses it instead.
    @Test func rk4PastTheStabilityLimitIsRefused() async throws {
        let plan = BiokineticsSimulationPlan(step: 1, final: 30, solver: .rungeKutta4(stepSize: 1))
        let result = try await solve(plan: plan, model: uraniumModel()).run()
        guard case let .failure(.unstableStep(step, limit)) = result else {
            Issue.record("expected .unstableStep, got \(result)")
            return
        }
        #expect(step == 1)
        #expect(limit < 0.08)
    }

    /// A rate of 5,000/day needs ~1,500 Dormand–Prince steps a day; the loose budget allows 50.
    @Test func rk45OutOfBudgetIsAFailureNotAFlatTail() async throws {
        let model = CompartmentalModel(
            nuclides: [],
            compartments: [
                Compartment(id: "a", nuclideId: "n0", name: "a", follow: true, intake: true, dispose: false, fraction: 1),
                Compartment(id: "b", nuclideId: "n0", name: "b", follow: true, intake: false, dispose: false, fraction: 0)
            ],
            connections: [CompartmentConnection(from: "a", to: "b", rate: 5_000)]
        )
        let plan = BiokineticsSimulationPlan(step: 1, final: 100, solver: .rungeKutta45(tolerance: 1e-10, budget: .loose))
        let result = await solve(plan: plan, model: model).run()
        guard case let .failure(.stepBudgetExhausted(reached, final, _)) = result else {
            Issue.record("expected .stepBudgetExhausted, got \(result)")
            return
        }
        #expect(reached < final)
    }

    @Test func theAutomaticBudgetFinishesThatStiffModel() async throws {
        let model = CompartmentalModel(
            nuclides: [],
            compartments: [
                Compartment(id: "a", nuclideId: "n0", name: "a", follow: true, intake: true, dispose: false, fraction: 1),
                Compartment(id: "b", nuclideId: "n0", name: "b", follow: true, intake: false, dispose: false, fraction: 0)
            ],
            connections: [CompartmentConnection(from: "a", to: "b", rate: 5_000)]
        )
        let plan = BiokineticsSimulationPlan(step: 1, final: 10, solver: .rungeKutta45(tolerance: 1e-10, budget: .automatic))
        let rows = try await solve(plan: plan, model: model).run().get()
        #expect(abs(rows[10][1] - 1) < 1e-9)
    }
}
