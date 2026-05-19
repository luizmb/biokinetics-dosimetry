import Calculus
import Foundation
import Math
import RealNumber
import RungeKutta

public enum SolverMethod: Equatable, Sendable {
    case birchall
    case rungeKutta4(stepSize: Double)
}

public struct InternalDosimetryCalculator {
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

    public func calculate(model: CompartmentalModel) -> [[Double]] {
        let A = model.coefficientMatrix(decay: lambdaR)
        let x0 = model.initialConditions()

        switch solver {
        case .birchall:
            return (0 ... stepCount + 1).map { i in
                Birchall.matrixExponential(Double(i * step) * A).apply(to: x0)
            }
        case .rungeKutta4(let h):
            let trajectory = RungeKutta4.trajectory(
                from: x0,
                derivative: { _, y in A.apply(to: y) },
                step: h,
                through: Double((stepCount + 1) * step)
            )
            let stepsPerOutput = Int((Double(step) / h).rounded())
            return (0 ... stepCount + 1).map { i in trajectory[i * stepsPerOutput].state }
        }
    }
}
