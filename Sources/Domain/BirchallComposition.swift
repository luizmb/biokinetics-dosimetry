public enum BirchallComposition: Equatable, Hashable, Sendable {
    /// Compute a fresh matrix exponential `exp(t·A)` at every output time.
    /// Numerically independent per row (no drift). Parallelised across the
    /// cooperative thread pool via `withTaskGroup`.
    case perTime

    /// Compute `exp(step·A)` once, then walk `[x₀, B·x₀, B²·x₀, …]`.
    /// ~60× faster on large horizons; small floating-point drift may
    /// accumulate for stiff systems or very long integrations.
    case semigroup
}
