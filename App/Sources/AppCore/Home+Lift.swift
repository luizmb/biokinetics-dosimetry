import FP
import HomeFeature
import SwiftRex
import SwiftRexArchitecture

public extension Module
where Action == HomeFeature.Action,
      State  == HomeFeature.State,
      Environment == HomeFeature.Environment {

    func lift() -> Module<AppAction, AppState, World, Content> {
        lift(
            action:      AppAction.prism.home,
            state:       AppState.lens.home,
            environment: { world in
                HomeModule.Environment(
                    xmlDecoder:       world.xmlDecoder,
                    jsonDecoder:      world.jsonDecoder,
                    newId:            world.newId,
                    seedId:           world.seedId,
                    saveDocument:     world.saveDocument,
                    loadAllDocuments: world.loadAllDocuments,
                    deleteDocument:   world.deleteDocument
                )
            }
        )
    }
}
