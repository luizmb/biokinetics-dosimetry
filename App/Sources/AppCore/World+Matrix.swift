import AppDomain
import CalculatorFeature
import DataStructure
import Foundation
import HomeFeature

// MARK: - DEBUG variants

#if DEBUG
/// The debug worlds' generator: a `Gen` on the system's randomness, like the real one.
private let matrixIDs = GenRunner(seed: nil)

extension World {

    public static var matrixFakeAll: World {
        let env = HomeModule.Environment.alwaysFails
        return World(
            xmlDecoder:   env.xmlDecoder,
            jsonDecoder:  env.jsonDecoder,
            newId:        { matrixIDs(Gen<AnyRandomNumberGenerator, UUID>.uuid()) },
            seedId:       { _ in matrixIDs(Gen<AnyRandomNumberGenerator, UUID>.uuid()) },
            formatDouble: { v, dp in String(format: "%.\(dp)f", v) },
            parseDouble:  { Double($0.replacingOccurrences(of: ",", with: ".")) },
            formatScientific: { v, dp in String(format: "%.\(dp)e", v) },
            formatInteger: { String($0) },
            formatSignificant: { String(format: "%.4g", $0) },
            deviceTraits: { .just(.initial) },
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
            newId:        { matrixIDs(Gen<AnyRandomNumberGenerator, UUID>.uuid()) },
            seedId:       { _ in matrixIDs(Gen<AnyRandomNumberGenerator, UUID>.uuid()) },
            formatDouble: { v, dp in String(format: "%.\(dp)f", v) },
            parseDouble:  { Double($0.replacingOccurrences(of: ",", with: ".")) },
            formatScientific: { v, dp in String(format: "%.\(dp)e", v) },
            formatInteger: { String($0) },
            formatSignificant: { String(format: "%.4g", $0) },
            deviceTraits: { .just(.initial) },
            solver:       CalculatorFeature.Environment.alwaysSucceed.solve,
            saveDocument: { _ in .success(()) },
            loadAllDocuments: { .success([]) },
            deleteDocument:   { _ in .success(()) }
        )
    }
}
#endif
