import CalculatorFeature
import Foundation
import HomeFeature

// MARK: - DEBUG variants

#if DEBUG
extension World {

    /// Combines fake decay-curve solver data with a never-decodes XML decoder.
    ///
    /// Use in tests that exercise app behaviour not involving real XML imports.
    /// Equivalent to `CalculatorFeature.Environment.alwaysSucceed` +
    /// `HomeModule.Environment.alwaysFails`.
    public static var matrixFakeAll: World {
        World(
            xmlDecoder: HomeModule.Environment.alwaysFails.xmlDecoder,
            solver: CalculatorFeature.Environment.alwaysSucceed.solve
        )
    }

    /// Combines fake decay-curve solver data with an XML decoder that always
    /// fails with the provided error.
    ///
    /// Use in tests that verify the import-failure path end-to-end.
    public static func matrixFailsImport(error: DecodingError) -> World {
        World(
            xmlDecoder: HomeModule.Environment.fails(error: error).xmlDecoder,
            solver: CalculatorFeature.Environment.alwaysSucceed.solve
        )
    }
}
#endif
