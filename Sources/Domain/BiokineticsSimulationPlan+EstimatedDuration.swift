#if canImport(Foundation)
import Foundation
#endif

extension BiokineticsSimulationPlan {

    // MARK: - Estimated duration

    /// Rough estimate of wall-clock time for this plan on the current device.
    ///
    /// The formula is calibrated from the `SolverBenchmarks` suite run on an
    /// Apple-Silicon Mac (Uranium model, n=19 compartments, final=1000 d):
    ///
    /// | Solver                    | Measured |
    /// |---------------------------|---------|
    /// | Birchall semigroup        | 0.30 s  |
    /// | Birchall perTime (conc.)  | 11.84 s |
    /// | RK4  (h=0.01)             | 167.61 s|
    /// | RK45 (tol=1e-10)          | 0.36 s  |
    ///
    /// **Accuracy:** ±50 % for semigroup and RK4 (analytic formula).
    /// RK45 assumes Uranium's stiffness: its step count follows the model's fastest rate.
    ///
    /// - Parameter compartmentCount: Total number of compartments in the model.
    /// - Returns: Estimated `TimeInterval` in seconds.
    public func estimatedDuration(compartmentCount: Int) -> TimeInterval {
        let n = Double(compartmentCount)
        let steps = Double(stepCount + 2)   // matches actual row count produced

        // Calibrated 2026-10-16 (FP 3, SwiftCalx 1.1, 16-core Intel, release) on Uranium, n = 19.
        switch solver {
        case .birchall(let composition):
            switch composition {
            case .semigroup:
                // One matrix exponential, then cheap mat-vecs: the exponential dominates.
                // n=19, 1000 days → 0.33 ms  →  C ≈ 4.8e-8·n³
                return 4.8e-8 * n * n * n

            case .perTime:
                // One matrix exponential per output row, spread over the cores.
                // n=19, 102 rows, 16 cores → 0.98 ms  →  C ≈ 2.2e-8·n³ per row per core
                let cores = Double(max(1, processorCount))
                return 2.2e-8 * n * n * n * steps / cores
            }

        case .rungeKutta4(let h):
            // The propagator: ~4 + 2·log₂(step/h) matrix products, then one mat-vec per row.
            // n=19, h=0.01, 102 rows → 69 µs.
            let stepsPerRow = max(1, (step / h).rounded())
            return 4.4e-10 * n * n * n * (4 + 2 * log2(stepsPerRow)) + 1e-9 * n * n * steps

        case .rungeKutta45:
            // ~3.1 µs a step at n=19 (≈ 8.6e-9·n²). The step count follows the model's fastest
            // rate, which isn't known here; this assumes Uranium's ~12.5 steps a day.
            return 8.6e-9 * n * n * 12.5 * final
        }
    }

    // MARK: - Warning thresholds

    /// User-facing severity category based on estimated duration.
    public enum DurationWarning: Equatable, Sendable {
        /// Under 3 seconds — no warning needed.
        case none
        /// 3–15 seconds — a brief notice is helpful.
        case brief
        /// 15–60 seconds — show a prominent banner, offer cancel.
        case slow
        /// Over 60 seconds — require explicit confirmation.
        case veryLong
    }

    /// Categorises the estimated duration into a UI warning level.
    public func durationWarning(compartmentCount: Int) -> DurationWarning {
        switch estimatedDuration(compartmentCount: compartmentCount) {
        case ..<3:     .none
        case 3..<15:   .brief
        case 15..<60:  .slow
        default:       .veryLong
        }
    }

    // MARK: - Private

    /// Active processor count for concurrency estimates.
    /// Falls back to 1 if Foundation is unavailable.
    private var processorCount: Int {
        #if canImport(Foundation)
        ProcessInfo.processInfo.activeProcessorCount
        #else
        1
        #endif
    }
}
