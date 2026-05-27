import FP
import Foundation
@preconcurrency import XMLCoder

extension World {
    public static var matrix: Self {
        .init(
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
