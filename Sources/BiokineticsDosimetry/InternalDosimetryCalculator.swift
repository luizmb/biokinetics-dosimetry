import Calculus
import CoreFP
import Foundation
import Math
import RealNumber
import RungeKutta

/// Birchall offers two equivalent ways to walk the linear-ODE trajectory once
/// the coefficient matrix `A` is built. Both reach the same answer; they trade
/// off cost, parallelism, and numerical drift differently.
public enum BirchallComposition: Equatable, Sendable {
    /// Compute a fresh matrix exponential `exp(t·A)` at every output time.
    ///
    /// Cost: `O(n)` independent matrix exponentials per call. Each is the
    /// expensive operation (Taylor series + scaling-and-squaring). On the
    /// Uranium 1000-day baseline this is ~190 seconds debug, ~tens of seconds
    /// release.
    ///
    /// Numerical: each output row is bounded by Birchall's own tolerance
    /// (`1e-10`) independently — no drift accumulates across rows.
    ///
    /// Parallelism: every output row is independent. The implementation uses
    /// `withTaskGroup` to spread the matrix exponentials across the
    /// cooperative thread pool. On a modern iPad with ~5–8 effective cores,
    /// expect ~5–8× speedup over a serial fold.
    case perTime

    /// Compute `B = exp(step·A)` *once*, then walk `[x₀, B·x₀, B²·x₀, …]` via
    /// `Matrix.actions(on:count:)`.
    ///
    /// Cost: one matrix exponential plus `n` mat-vecs. Mat-vecs are `O(rows²)`;
    /// the matrix-exponential cost dominates `n` mat-vec costs unless `n` is
    /// tiny. On the Uranium 1000-day baseline this is ~3 seconds debug
    /// (≈60× faster than `.perTime`); essentially algorithmic for large `n`.
    ///
    /// Numerical: floating-point error in the iterated mat-vec accumulates as
    /// roughly `n · ε · κ(B)`. For well-conditioned `B` (small `‖A‖`, modest
    /// `n`) the drift is invisible. For stiff systems (large `κ`) or very long
    /// horizons the drift can be visible; compare against `.perTime` to spot
    /// when this matters.
    ///
    /// Parallelism: the iteration is strictly sequential — each step depends
    /// on the previous one. No SMP win available without changing the
    /// algorithm.
    case semigroup
}

public enum SolverMethod: Equatable, Sendable {
    case birchall(composition: BirchallComposition)
    case rungeKutta4(stepSize: Double)
    case rungeKutta45(tolerance: Double)
}

extension SolverMethod {
    /// Convenience constructor for the default Birchall composition (`.perTime`).
    public static var birchall: SolverMethod { .birchall(composition: .perTime) }
}

public struct InternalDosimetryCalculator: Sendable {
    public let step: Int
    public let halfLife: Double
    public let final: Int
    public let lambdaR: Double
    public let solver: SolverMethod

    public init(step: Int, halfLife: Double, final: Int, solver: SolverMethod = .birchall) {
        self.step = step
        self.halfLife = halfLife
        self.final = final
        self.lambdaR = halfLife > 0 ? log(2) / halfLife : 0
        self.solver = solver
    }

    public var stepCount: Int { final / step }

    /// Returns a lazy ``DeferredTask`` that, when run, computes the trajectory
    /// of compartment activities for `model` under the selected solver.
    ///
    /// Nothing executes until the caller invokes `.run()` (or `.eraseToTask()`).
    /// This keeps the calculator pure-functional from the caller's perspective:
    /// `calculate(model:)` is referentially transparent, the returned task can
    /// be passed around, stored, mapped over, and composed with other
    /// `DeferredTask`s before any work happens.
    ///
    /// Inside the task body the parallelisable solvers (Birchall `.perTime`)
    /// use Swift Concurrency's `withTaskGroup` to spread independent matrix
    /// exponentials across the cooperative thread pool — no
    /// `DispatchSemaphore` bridging, no `UnsafeMutableBufferPointer`,
    /// no `@unchecked Sendable`.
    public func calculate(model: CompartmentalModel) -> DeferredTask<[[Double]]> {
        let A = model.coefficientMatrix(decay: lambdaR)
        let x0 = model.initialConditions()
        let step = self.step
        let stepCount = self.stepCount
        let solver = self.solver

        return DeferredTask {
            switch solver {
            case .birchall(.perTime):
                await birchallPerTime(A: A, x0: x0, step: step, stepCount: stepCount)
            case .birchall(.semigroup):
                birchallSemigroup(A: A, x0: x0, step: step, stepCount: stepCount)
            case .rungeKutta4(let h):
                rungeKutta4(A: A, x0: x0, step: step, stepCount: stepCount, h: h)
            case .rungeKutta45(let tolerance):
                rungeKutta45(A: A, x0: x0, step: step, stepCount: stepCount, tolerance: tolerance)
            }
        }
    }
}

// MARK: - Solver implementations

/// Independent `exp(i·step·A) · x₀` per output row, parallelised across the
/// cooperative thread pool with `withTaskGroup`. Each child task is one
/// matrix exponential plus one mat-vec; they're all independent, so the
/// group fans out by core count and the results are reassembled in order.
private func birchallPerTime(
    A: Matrix<Double>,
    x0: [Double],
    step: Int,
    stepCount: Int
) async -> [[Double]] {
    let outputCount = stepCount + 2
    return await withTaskGroup(of: (Int, [Double]).self, returning: [[Double]].self) { group in
        for i in 0 ..< outputCount {
            group.addTask {
                let row = Birchall.matrixExponential(Double(i * step) * A).apply(to: x0)
                return (i, row)
            }
        }
        var results = Array(repeating: [Double](), count: outputCount)
        for await (i, row) in group {
            results[i] = row
        }
        return results
    }
}

/// One matrix exponential up front, then iterated mat-vec via
/// `Matrix.actions(on:count:)`. Strictly sequential; trades algorithmic
/// speed for accumulated floating-point drift across the chain.
private func birchallSemigroup(
    A: Matrix<Double>,
    x0: [Double],
    step: Int,
    stepCount: Int
) -> [[Double]] {
    let stepper = Birchall.matrixExponential(Double(step) * A)
    return stepper.actions(on: x0, count: stepCount + 1)
}

// Both RK solvers route through ``AcceleratedVector`` for the state type so
// every per-stage `+` / scalar `*` goes through vDSP on Apple platforms via
// the protocol witness. `x0` is wrapped once at the boundary; the derivative
// returns `AcceleratedVector` via the ``Matrix.apply(to: AcceleratedVector)``
// bridge overload (zero-copy — same COW buffer underneath); only the public
// `[[Double]]` boundary unwraps.
//
// Birchall paths (`perTime`, `semigroup`) stay on `[Double]` because their hot
// path is mat-vec (`Matrix.apply(to: [Double])`), which is already routed to
// `cblas_dgemv` on Apple — there's no per-stage vector arithmetic to gain
// from `AcceleratedVector`.

private func rungeKutta4(
    A: Matrix<Double>,
    x0: [Double],
    step: Int,
    stepCount: Int,
    h: Double
) -> [[Double]] {
    let trajectory = RungeKutta4.trajectory(
        from: x0.asAcceleratedVector,
        derivative: { _, y in A.apply(to: y) },
        step: h,
        through: Double((stepCount + 1) * step)
    )
    let stepsPerOutput = Int((Double(step) / h).rounded())
    return (0 ... stepCount + 1).map { i in trajectory[i * stepsPerOutput].state.storage }
}

private func rungeKutta45(
    A: Matrix<Double>,
    x0: [Double],
    step: Int,
    stepCount: Int,
    tolerance: Double
) -> [[Double]] {
    let outputTimes = (0 ... stepCount + 1).map { Double($0 * step) }
    return RungeKutta45.trajectory(
        at: outputTimes,
        from: x0.asAcceleratedVector,
        derivative: { _, y in A.apply(to: y) },
        tolerance: tolerance
    ).map(\.storage)
}
