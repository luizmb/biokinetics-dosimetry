import CalculatorFeature
import SwiftRexArchitecture

public extension FeatureHost
where Action == CalculatorFeature.Action,
      State == CalculatorFeature.State,
      Environment == CalculatorFeature.Environment {
    static var calculator: Self { .init(CalculatorFeature.self) }
}
