import FP
import HomeFeature
import SwiftRex
import SwiftRexArchitecture

public let homeScope = Scope<AppAction, AppState, World, HomeFeature>(
    HomeFeature.self,
    action: \.home,
    state: \.home,
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
