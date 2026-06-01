import AppDomain
import CalculatorFeature
import Foundation
import HomeFeature

// MARK: - DEBUG variants

#if DEBUG
extension World {

    public static var matrixFakeAll: World {
        World(
            xmlDecoder: HomeModule.Environment.alwaysFails.xmlDecoder,
            solver: CalculatorFeature.Environment.alwaysSucceed.solve,
            saveDocument: { _ in Result<Void, PersistenceError>.success(()) },
            loadAllDocuments: { Result<[ModelDocument], PersistenceError>.success([]) },
            deleteDocument: { _ in Result<Void, PersistenceError>.success(()) }
        )
    }

    public static func matrixFailsImport(error: DecodingError) -> World {
        World(
            xmlDecoder: HomeModule.Environment.fails(error: error).xmlDecoder,
            solver: CalculatorFeature.Environment.alwaysSucceed.solve,
            saveDocument: { _ in Result<Void, PersistenceError>.success(()) },
            loadAllDocuments: { Result<[ModelDocument], PersistenceError>.success([]) },
            deleteDocument: { _ in Result<Void, PersistenceError>.success(()) }
        )
    }
}
#endif
