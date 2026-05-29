/// DEBUG-only mock factories for `CalculatorFeature.Environment`.
///
/// Use these in unit tests and SwiftUI previews instead of inline closures.
#if DEBUG
import Darwin  // exp
import Domain  // BiokineticsSimulationPlan
import FP      // DeferredTask
import Solver  // Solver.solve

public extension CalculatorFeature.Environment {

    /// Returns plausible exponential-decay curves for every solve request.
    ///
    /// The curves follow `value[i](t) = max(0, exp(-(0.05 + i·0.03)·t) − i·0.1)`,
    /// giving visually distinct compartment series. Useful for snapshot tests
    /// and SwiftUI previews.
    static var alwaysSucceed: CalculatorFeature.Environment {
        .init { plan, model in
            let n     = model.compartments.count
            let steps = plan.stepCount + 1
            return DeferredTask {
                (0..<steps).map { step in
                    let t = Double(step) * plan.step
                    return (0..<n).map { idx in
                        let k = 0.05 + Double(idx) * 0.03
                        return max(0, exp(-k * t) - Double(idx) * 0.1)
                    }
                }
            }
        }
    }

    /// Returns the provided data for every solve request, ignoring the plan and model.
    ///
    /// Use in unit tests that need deterministic, pre-specified results.
    static func succeeds(with data: [[Double]]) -> CalculatorFeature.Environment {
        .init { _, _ in DeferredTask { data } }
    }

    /// Returns an empty result set for every solve request.
    ///
    /// Simulates a solver that produces no output rows — for example, an
    /// empty model or zero-duration plan.
    static var alwaysFails: CalculatorFeature.Environment {
        .init { _, _ in DeferredTask { [] } }
    }

    /// Runs the real Birchall solver (perTime composition) for every solve request.
    ///
    /// Use in snapshot and integration tests where you want actual solver output
    /// rather than pre-seeded fake curves.  Results match the `ipen-validator`
    /// C# reference to within `1e-5`.
    static var realBirchall: CalculatorFeature.Environment {
        .init { plan, model in
            let realPlan = BiokineticsSimulationPlan(
                step: plan.step,
                final: plan.final,
                solver: .birchall(composition: .perTime)
            )
            return DeferredTask { await Solver.solve(plan: realPlan, model: model).run() }
        }
    }
}

#endif
