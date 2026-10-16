import Calculus
import CoreFP
import ReactiveConcurrency
import Domain
import Math
import RungeKutta

/// Runs a biokinetic simulation and returns the compartment trajectory.
///
/// Returns a `DeferredTask` — nothing executes until `.run()` is called.
/// The returned matrix has shape `[stepCount + 2][compartmentCount]`:
/// rows are time points `0, step, 2·step, …, (stepCount+1)·step`, columns are compartments
/// in the same order as `model.compartments`.
///
/// Radioactive decay constants are derived from each compartment's parent `Nuclide`
/// inside the model — `plan` no longer carries a `halfLife` parameter.
///
/// - Parameters:
///   - plan: Simulation configuration (step, final, solver method).
///   - model: The compartmental model to simulate. Must have at least one intake
///     compartment set via `updatingCompartment(id:_:)` before calling.
public func solve(
    plan: BiokineticsSimulationPlan,
    model: CompartmentalModel
) -> DeferredTask<Result<[[Double]], SolveError>> {
    let system = model.linearSystem()
    let limits = model.solverLimits
    let step = plan.step
    let stepCount = plan.stepCount
    let solver = plan.solver

    return DeferredTask {
        switch solver {
        case .birchall(.perTime):
            .success(await birchallPerTime(A: system.matrix, x0: system.initialConditions, step: step, stepCount: stepCount))
        case .birchall(.semigroup):
            .success(birchallSemigroup(A: system.matrix, x0: system.initialConditions, step: step, stepCount: stepCount))
        case .rungeKutta4(let h):
            rungeKutta4(A: system.matrix, x0: system.initialConditions, step: step, stepCount: stepCount, h: h)
        case let .rungeKutta45(tolerance, budget):
            rungeKutta45(A: system.matrix, x0: system.initialConditions, step: step, stepCount: stepCount, tolerance: tolerance, budget: budget, limits: limits)
        }
    }
}

// MARK: - Birchall paths

/// Independent `exp(i·step·A) · x₀` per output row, parallelised across the
/// cooperative thread pool with `withTaskGroup`.
private func birchallPerTime(
    A: Matrix<Double>,
    x0: [Double],
    step: Double,
    stepCount: Int
) async -> [[Double]] {
    let outputCount = stepCount + 2
    return await withTaskGroup(of: (Int, [Double]).self, returning: [[Double]].self) { group in
        for i in 0 ..< outputCount {
            group.addTask {
                let row = Birchall.matrixExponential(Double(i) * step * A).apply(to: x0)
                return (i, row)
            }
        }
        var results = Array(repeating: [Double](), count: outputCount)
        for await (i, row) in group { results[i] = row }
        return results
    }
}

/// One matrix exponential up front, then iterated mat-vec via
/// `Matrix.actions(on:count:)`.
private func birchallSemigroup(
    A: Matrix<Double>,
    x0: [Double],
    step: Double,
    stepCount: Int
) -> [[Double]] {
    Birchall.matrixExponential(step * A).actions(on: x0, count: stepCount + 1)
}

// MARK: - Runge-Kutta paths

/// RK4 on `dx/dt = A·x` through SwiftCalx's linear propagator: `P^(step/h)` once, then one
/// matrix-vector product per output row. Refuses a step past the stability limit, where RK4's
/// result grows without bound (h = 1 d on a model with rates of 35/day reaches 1e146 by day 30).
private func rungeKutta4(
    A: Matrix<Double>,
    x0: [Double],
    step: Double,
    stepCount: Int,
    h: Double
) -> Result<[[Double]], SolveError> {
    let stableLimit = rk4StabilityInterval / spectralBound(A)
    guard h > 0, h < stableLimit else { return .failure(.unstableStep(step: h, stableLimit: stableLimit)) }
    let stepsPerSample = max(1, Int((step / h).rounded()))
    return .success(RungeKutta4.linearTrajectory(of: A, from: x0, step: h, stepsPerSample: stepsPerSample, count: stepCount + 1))
}

// RK45 routes through `AcceleratedVector` so every per-stage `+` / scalar `*` goes through vDSP on
// Apple platforms.

private func rungeKutta45(
    A: Matrix<Double>,
    x0: [Double],
    step: Double,
    stepCount: Int,
    tolerance: Double,
    budget: StepBudget,
    limits: SolverLimits
) -> Result<[[Double]], SolveError> {
    let outputTimes = (0 ... stepCount + 1).map { Double($0) * step }
    let finalDay = outputTimes.last ?? 0
    return RungeKutta45.trajectory(
        at: outputTimes,
        from: x0.asAcceleratedVector,
        derivative: { _, y in A.apply(to: y) },
        tolerance: tolerance,
        maxIterations: budget.steps(limits: limits, days: finalDay)
    )
    .map { $0.map(\.storage) }
    .mapError { failure in
        switch failure {
        case let .stepLimit(reached, steps): .stepBudgetExhausted(reachedDay: reached, finalDay: finalDay, steps: steps)
        case let .stepUnderflow(at, _): .stepUnderflow(day: at)
        }
    }
}
