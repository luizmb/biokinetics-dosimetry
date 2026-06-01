import Domain

extension CompartmentalModel {
    /// Converts a raw ODE trajectory into display-ready values.
    ///
    /// For regular compartments the raw accumulated quantity is returned unchanged.
    /// For sink (`dispose == true`) compartments the quantity is replaced by the
    /// average excretion rate over each step interval (finite-difference dQ/dt),
    /// matching conventional bioassay reporting where urine/feces values decrease
    /// as source compartments deplete — consistent with the reference C# implementation.
    ///
    /// - Parameters:
    ///   - trajectory: Raw solver output — `trajectory[stepIndex][compartmentIndex]`.
    ///   - step: Time interval between consecutive rows, in days.
    /// - Returns: Trajectory with the same shape; sink columns replaced by rates.
    public func displayTrajectory(from trajectory: [[Double]], step: Double) -> [[Double]] {
        let sinkIndices = Set(
            compartments.indices.filter { compartments[$0].dispose }
        )
        guard !sinkIndices.isEmpty else { return trajectory }

        return trajectory.enumerated().map { rowIdx, row in
            guard rowIdx > 0 else { return row }
            let prev = trajectory[rowIdx - 1]
            return row.indices.map { col in
                sinkIndices.contains(col) ? (row[col] - prev[col]) / step : row[col]
            }
        }
    }
}
