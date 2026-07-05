import EditorFeature
import SwiftRex
import SwiftRexArchitecture

public let editorScope = Scope<AppAction, AppState, World, EditorFeature>(
    EditorFeature.self,
    action: \.editor,
    state: \.editor,
    environment: { world in EditorFeature.Environment(newId: world.newId) }
)
