import AppDomain
import CalculatorFeature
import Foundation
import HomeFeature

// MARK: - DEBUG variants

#if DEBUG
extension World {

    public static var matrixFakeAll: World {
        let env = HomeModule.Environment.alwaysFails
        return World(
            xmlDecoder:   env.xmlDecoder,
            jsonDecoder:  env.jsonDecoder,
            newId:        { UUID() },
            seedId:       { _ in UUID() },
            formatDouble: { v, dp in String(format: "%.\(dp)f", v) },
            parseDouble:  { Double($0.replacingOccurrences(of: ",", with: ".")) },
            solver:       CalculatorFeature.Environment.alwaysSucceed.solve,
            saveDocument: { _ in .success(()) },
            loadAllDocuments: { .success([]) },
            deleteDocument:   { _ in .success(()) }
        )
    }

    public static func matrixFailsImport(error: DecodingError) -> World {
        let env = HomeModule.Environment.fails(error: error)
        return World(
            xmlDecoder:   env.xmlDecoder,
            jsonDecoder:  env.jsonDecoder,
            newId:        { UUID() },
            seedId:       { _ in UUID() },
            formatDouble: { v, dp in String(format: "%.\(dp)f", v) },
            parseDouble:  { Double($0.replacingOccurrences(of: ",", with: ".")) },
            solver:       CalculatorFeature.Environment.alwaysSucceed.solve,
            saveDocument: { _ in .success(()) },
            loadAllDocuments: { .success([]) },
            deleteDocument:   { _ in .success(()) }
        )
    }
}
#endif
