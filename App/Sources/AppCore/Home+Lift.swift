import FP
import HomeFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftUI

public extension Module
where Action == HomeFeature.Action,
      State  == HomeFeature.State,
      Environment == HomeFeature.Environment {

    func lift() -> Module<AppAction, AppState, World, AnyView> {
        lift(
            action:      AppAction.prism.home,
            state:       AppState.lens.home,
            environment: \.xmlDecoder >>> HomeFeature.Environment.init
        ).eraseToAnyView()
    }
}
