/// DEBUG-only mock factories for `CalculatorFeature.Environment`.
///
/// Use these in unit tests and SwiftUI previews instead of inline closures.
#if DEBUG
import AppDomain   // CalculatorExportData, FieldLingo
import Darwin      // exp
import Domain      // CompartmentalModel, BiokineticsSimulationPlan
import Foundation  // Data
import FP          // DeferredTask
import Solver      // Solver.solve

// Mock solver — exponential decay per compartment
private func mockDecay(plan: BiokineticsSimulationPlan, model: CompartmentalModel) -> DeferredTask<[[Double]]> {
    let n = model.compartments.count
    let steps = plan.stepCount + 1
    return DeferredTask {
        (0..<steps).map { step -> [Double] in
            let t = Double(step) * plan.step
            return (0..<n).map { idx -> Double in
                let k = 0.05 + Double(idx) * 0.03
                return max(0, exp(-k * t) - Double(idx) * 0.1)
            }
        }
    }
}
private let mockSolve: @Sendable (BiokineticsSimulationPlan, CompartmentalModel) -> DeferredTask<[[Double]]> = mockDecay

// No-op export stubs — mocks don't need real CSV/PDF output.
private let stubCSV: @Sendable (CalculatorExportData) -> DeferredTask<Result<Data, Error>> = { _ in
    DeferredTask { .success(Data()) }
}
private let stubPDF: @Sendable (CalculatorExportData) -> DeferredTask<Result<Data, Error>> = { _ in
    DeferredTask { .success(Data()) }
}

public extension CalculatorFeature.Environment {

    /// Returns plausible exponential-decay curves for every solve request.
    static var alwaysSucceed: CalculatorFeature.Environment {
        .init(
            solve: mockSolve,
            generateCSV: stubCSV,
            renderPDF:   stubPDF
        )
    }

    /// Returns the provided data for every solve request, ignoring the plan and model.
    static func succeeds(with data: [[Double]]) -> CalculatorFeature.Environment {
        .init(solve: { _, _ in DeferredTask { data } },
              generateCSV: stubCSV, renderPDF: stubPDF)
    }

    static var alwaysFails: CalculatorFeature.Environment {
        .init(solve: { _, _ in DeferredTask { [] } },
              generateCSV: stubCSV, renderPDF: stubPDF)
    }

    static var realBirchall: CalculatorFeature.Environment {
        .init(
            solve: { plan, model in
                let p = BiokineticsSimulationPlan(step: plan.step, final: plan.final,
                                                  solver: .birchall(composition: .perTime))
                return DeferredTask { await Solver.solve(plan: p, model: model).run() }
            },
            generateCSV: stubCSV,
            renderPDF:   stubPDF
        )
    }
}

#endif
