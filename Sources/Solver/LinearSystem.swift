import Math
import RealNumber

/// The math primitive both Birchall and Runge-Kutta solvers accept.
///
/// Produced by `CompartmentalModel.linearSystem(decay:)` in this module.
/// Contains no domain concepts — just the coefficient matrix `A` and the
/// initial state vector `x₀` for the ODE `dx/dt = A·x, x(0) = x₀`.
public struct LinearSystem: Sendable {
    /// Coefficient matrix `A` encoding transfer rates and radioactive decay.
    public let matrix: Matrix<Double>
    /// Initial compartment amounts `x₀`.
    public let initialConditions: [Double]

    public init(matrix: Matrix<Double>, initialConditions: [Double]) {
        self.matrix = matrix
        self.initialConditions = initialConditions
    }
}
