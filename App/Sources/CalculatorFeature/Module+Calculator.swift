import SwiftRexArchitecture

public extension Module
where Action == CalculatorFeature.Action,
      State == CalculatorFeature.State,
      Environment == CalculatorFeature.Environment,
      Content == CalculatorFeature.Content {
    static var calculator: Self { .init(CalculatorFeature.self) }
}
