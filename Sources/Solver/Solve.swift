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
) -> DeferredTask<[[Double]]> {
    let system = model.linearSystem()
    let step = plan.step
    let stepCount = plan.stepCount
    let solver = plan.solver

    return DeferredTask {
        switch solver {
        case .birchall(.perTime):
            await birchallPerTime(A: system.matrix, x0: system.initialConditions, step: step, stepCount: stepCount)
        case .birchall(.semigroup):
            birchallSemigroup(A: system.matrix, x0: system.initialConditions, step: step, stepCount: stepCount)
        case .rungeKutta4(let h):
            rungeKutta4(A: system.matrix, x0: system.initialConditions, step: step, stepCount: stepCount, h: h)
        case .rungeKutta45(let tolerance):
            rungeKutta45(A: system.matrix, x0: system.initialConditions, step: step, stepCount: stepCount, tolerance: tolerance)
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

/// RK4 on `dx/dt = A·x`, evaluated as its propagator.
///
/// For a linear autonomous system one RK4 step of size `h` is exactly `y ↦ P·y` with
/// `P = I + hA + (hA)²/2 + (hA)³/6 + (hA)⁴/24` (the method's stability polynomial), so `step / h`
/// steps are `P^(step/h)`: built once by repeated squaring, then walked one matrix-vector product
/// per output row. Same method and the same truncation error as stepping it (measured on Uranium,
/// 100 days, h=0.01: within 7e-15 of the stepped trajectory), without the per-stage vectors.
private func rungeKutta4(
    A: Matrix<Double>,
    x0: [Double],
    step: Double,
    stepCount: Int,
    h: Double
) -> [[Double]] {
    let identity = Matrix<Double>.identity(size: A.rows)
    let propagator = identity + (h * A) * (identity + (h / 2 * A) * (identity + (h / 3 * A) * (identity + (h / 4) * A)))
    return power(propagator, Int((step / h).rounded())).actions(on: x0, count: stepCount + 1)
}

/// `M^exponent` by repeated squaring (`exponent ≥ 0`).
private func power(_ matrix: Matrix<Double>, _ exponent: Int) -> Matrix<Double> {
    var (result, base, remaining) = (Matrix<Double>.identity(size: matrix.rows), matrix, exponent)
    while remaining > 0 {
        if remaining & 1 == 1 { result *= base }
        base *= base
        remaining >>= 1
    }
    return result
}

// RK45 routes through `AcceleratedVector` so every per-stage `+` / scalar `*` goes through vDSP on
// Apple platforms.

private func rungeKutta45(
    A: Matrix<Double>,
    x0: [Double],
    step: Double,
    stepCount: Int,
    tolerance: Double
) -> [[Double]] {
    let outputTimes = (0 ... stepCount + 1).map { Double($0) * step }
    return RungeKutta45.trajectory(
        at: outputTimes,
        from: x0.asAcceleratedVector,
        derivative: { _, y in A.apply(to: y) },
        tolerance: tolerance
    ).map(\.storage)
}
