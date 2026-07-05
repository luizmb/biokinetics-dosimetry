import CalculatorFeature
import FP
import SwiftRex
import SwiftRexArchitecture

public let calculatorScope = Scope<AppAction, AppState, World, CalculatorFeature>(
    CalculatorFeature.self,
    action: \.calculator,
    state: \.calculator,
    environment: { world in
                CalculatorFeature.Environment(
                    solve:        world.solver,
                    formatDouble: world.formatDouble,
                    parseDouble:  world.parseDouble
                )
            }
)
