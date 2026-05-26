import EditorFeature
import FP
import SwiftRex
import SwiftRexArchitecture
import SwiftUI

public extension Module
where Action == EditorFeature.Action,
      State  == EditorFeature.State,
      Environment == EditorFeature.Environment {

    func lift() -> Module<AppAction, AppState, World, AnyView> {
        lift(
            action:      AppAction.prism.editor,
            state:       AppState.lens.editor,
            environment: ignore
        ).eraseToAnyView()
    }
}
