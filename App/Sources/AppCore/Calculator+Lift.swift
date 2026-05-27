import CalculatorFeature
import FP
import SwiftRex
import SwiftRexArchitecture

public extension Module
where Action == CalculatorFeature.Action,
      State  == CalculatorFeature.State,
      Environment == CalculatorFeature.Environment {

    func lift() -> Module<AppAction, AppState, World, Content> {
        lift(
            action:      AppAction.prism.calculator,
            state:       AppState.lens.calculator,
            environment: \.solver >>> CalculatorFeature.Environment.init
        )
    }
}
