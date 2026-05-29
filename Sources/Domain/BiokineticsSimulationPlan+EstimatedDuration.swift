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
    /// RK45 is conservatively over-estimated because its adaptive step count
    /// depends on system stiffness, which varies by model.
    ///
    /// - Parameter compartmentCount: Total number of compartments in the model.
    /// - Returns: Estimated `TimeInterval` in seconds.
    public func estimatedDuration(compartmentCount: Int) -> TimeInterval {
        let n = Double(compartmentCount)
        let steps = Double(stepCount + 2)   // matches actual row count produced

        switch solver {
        case .birchall(let composition):
            switch composition {
            case .semigroup:
                // One matrix exponential O(n³·taylorIter), then cheap O(n²·steps) applies.
                // The exp dominates for any realistic stepCount.
                // Calibrated: n=19 → 0.30 s  →  C ≈ 43.8 µs·n⁻³
                return 4.38e-5 * n * n * n

            case .perTime:
                // One independent matrix exponential per output step, parallelised.
                // Calibrated: n=19, steps=1002 → 11.84 s (≈8 cores)
                // C ≈ 13.8 µs·cores·n⁻³·steps⁻¹
                let cores = Double(max(1, processorCount))
                return 1.38e-5 * n * n * n * steps / cores
            }

        case .rungeKutta4(let h):
            // Fixed-step: strictly O(n² × final/h).
            // Calibrated: n=19, h=0.01, final=1000 → 167.61 s
            // C ≈ 4.64 µs·n⁻²·innerStep⁻¹
            let innerSteps = final / h
            return 4.64e-6 * n * n * innerSteps

        case .rungeKutta45:
            // Adaptive step count depends on system stiffness — cannot be predicted
            // analytically.  For biokinetic models RK45 was ~0.36 s (n=19, final=1000),
            // but conservatively assume up to 3× the semigroup estimate so the UI
            // never under-warns.
            return 3.0 * 4.38e-5 * n * n * n
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
