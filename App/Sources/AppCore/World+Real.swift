import Solver
@preconcurrency import XMLCoder

// MARK: - World (live)

/// The only file in AppCore that imports concrete third-party dependencies.
/// All other files depend only on protocols / our own modules.
extension World {
    public static var real: Self {
        .init(
            xmlDecoder: XMLDecoder(),
            solver: { plan, model in Solver.solve(plan: plan, model: model) }
        )
    }
}
