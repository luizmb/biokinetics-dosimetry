import EditorFeature
import FP
import SwiftRex
import SwiftRexArchitecture

public extension Module
where Action == EditorFeature.Action,
      State  == EditorFeature.State,
      Environment == EditorFeature.Environment {

    func lift() -> Module<AppAction, AppState, World, Content> {
        lift(
            action:      AppAction.prism.editor,
            state:       AppState.lens.editor,
            environment: ignore
        )
    }
}
