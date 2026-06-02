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
            xmlDecoder:  env.xmlDecoder,
            jsonDecoder: env.jsonDecoder,
            newId:       { UUID() },
            solver:      CalculatorFeature.Environment.alwaysSucceed.solve,
            generateCSV: CalculatorFeature.Environment.alwaysSucceed.generateCSV,
            renderPDF:   CalculatorFeature.Environment.alwaysSucceed.renderPDF,
            saveDocument: { _ in .success(()) },
            loadAllDocuments: { .success([]) },
            deleteDocument: { _ in .success(()) }
        )
    }

    public static func matrixFailsImport(error: DecodingError) -> World {
        let env = HomeModule.Environment.fails(error: error)
        return World(
            xmlDecoder:  env.xmlDecoder,
            jsonDecoder: env.jsonDecoder,
            newId:       { UUID() },
            solver:      CalculatorFeature.Environment.alwaysSucceed.solve,
            generateCSV: CalculatorFeature.Environment.alwaysSucceed.generateCSV,
            renderPDF:   CalculatorFeature.Environment.alwaysSucceed.renderPDF,
            saveDocument: { _ in .success(()) },
            loadAllDocuments: { .success([]) },
            deleteDocument: { _ in .success(()) }
        )
    }
}
#endif
