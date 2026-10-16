public enum SolverMethod: Equatable, Hashable, Sendable {
    case birchall(composition: BirchallComposition)
    /// Classical fixed-step RK4 with integration step `stepSize` (days), independent of the output
    /// step. It has to stay inside the model's stability limit; the solver refuses a larger one.
    case rungeKutta4(stepSize: Double)
    /// Adaptive Dormand–Prince 5(4): `tolerance` bounds each step's absolute error estimate,
    /// `budget` how many steps it may take before reporting that it couldn't finish.
    case rungeKutta45(tolerance: Double, budget: StepBudget)
}

extension SolverMethod {
    /// Convenience: Birchall with the default `.perTime` composition.
    public static var birchall: SolverMethod { .birchall(composition: .perTime) }
}

/// How many steps RK45 may take. On a stiff model an explicit method is held near its stability
/// limit whatever the tolerance asks for, so the steps it needs grow with the simulated days times
/// the model's fastest rate.
public enum StepBudget: Equatable, Hashable, Sendable {
    /// Sized from the model: four times the steps its fastest rate implies over the horizon.
    case automatic
    /// At most `stepsPerDay` per simulated day: a cap on how long a run may take. Below what the
    /// model needs, the run stops early and says where.
    case manual(stepsPerDay: Int)
}
