import CalculatorFeature
import FP
import Foundation
import HomeFeature
@preconcurrency import XMLCoder

extension World {
    public static var matrix: World {
        World(
            xmlDecoder: XMLDecoder(),
            solver: { plan, model in
                // Return plausible fake data for previews
                let n = model.compartments.count
                let steps = plan.stepCount + 1
                return DeferredTask {
                    (0..<steps).map { step in
                        let t = Double(step * plan.step)
                        return (0..<n).map { idx in
                            let k = 0.05 + Double(idx) * 0.03
                            return max(0, exp(-k * t) - Double(idx) * 0.1)
                        }
                    }
                }
            }
        )
    }
}

// MARK: - DEBUG variants

#if DEBUG
extension World {

    /// Combines fake decay-curve solver data with a never-decodes XML decoder.
    ///
    /// Use in tests that exercise app behaviour not involving real XML imports.
    /// Equivalent to `CalculatorFeature.Environment.alwaysSucceed` +
    /// `HomeModule.Environment.alwaysFails`.
    public static var matrixFakeAll: World {
        World(
            xmlDecoder: HomeModule.Environment.alwaysFails.xmlDecoder,
            solver: CalculatorFeature.Environment.alwaysSucceed.solve
        )
    }

    /// Combines fake decay-curve solver data with an XML decoder that always
    /// fails with the provided error.
    ///
    /// Use in tests that verify the import-failure path end-to-end.
    public static func matrixFailsImport(error: DecodingError) -> World {
        World(
            xmlDecoder: HomeModule.Environment.fails(error: error).xmlDecoder,
            solver: CalculatorFeature.Environment.alwaysSucceed.solve
        )
    }
}
#endif
