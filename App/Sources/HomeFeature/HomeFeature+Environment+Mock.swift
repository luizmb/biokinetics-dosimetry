/// DEBUG-only mock factories for `HomeModule.Environment`.
///
/// Use these in unit tests and SwiftUI previews instead of inline
/// `DataDecoderFactory` implementations.
#if DEBUG
import Core       // DataDecoderFactory, DataDecoder, Convert
import Foundation // DecodingError
import Parser     // IpenXmlModel

// MARK: - Public factories

public extension HomeModule.Environment {

    /// Succeeds for every XML import, producing a document from the given
    /// `IpenXmlModel` fixture (ignoring the actual imported data).
    ///
    /// Use in tests or previews that need to observe a successful import result
    /// without providing real XML bytes.
    static func alwaysSucceed(importing model: IpenXmlModel) -> HomeModule.Environment {
        HomeModule.Environment(xmlDecoder: AlwaysSucceedsFactory(model: model))
    }

    /// Succeeds for every XML import with a minimal empty model (no compartments).
    ///
    /// The resulting document has an empty `CompartmentalModel`, so it is only
    /// useful for tests that verify the import lifecycle and do not inspect
    /// the resulting document's contents.
    static var alwaysSucceed: HomeModule.Environment {
        alwaysSucceed(importing: IpenXmlModel(compartments: [], connections: []))
    }

    /// Fails every XML import with a generic `dataCorrupted` error.
    ///
    /// Use in tests or previews that never call `importXML`, to avoid providing
    /// a real decoder. The factory is never invoked in such scenarios.
    static var alwaysFails: HomeModule.Environment {
        HomeModule.Environment(xmlDecoder: AlwaysFailsFactory(
            error: .dataCorrupted(.init(codingPath: [], debugDescription: "HomeModule.Environment.alwaysFails"))
        ))
    }

    /// Fails every XML import with the provided error.
    ///
    /// Use in tests that verify the import-failure path with a specific error value.
    static func fails(error: DecodingError) -> HomeModule.Environment {
        HomeModule.Environment(xmlDecoder: AlwaysFailsFactory(error: error))
    }
}

// MARK: - Private helpers

private struct AlwaysFailsFactory: DataDecoderFactory, Sendable {
    let error: DecodingError

    func dataDecoder<Output: Decodable>(for type: Output.Type) -> DataDecoder<Output> {
        Convert { _ in .failure(error) }
    }
}

/// A `DataDecoderFactory` that returns a pre-built model for any decode request.
///
/// The conditional cast (`model as? Output`) succeeds when the behaviour requests
/// `IpenXmlModel` (the type `HomeFeature.behavior()` always uses). For any other
/// type it falls back to a `dataCorrupted` failure, keeping the mock safe even if
/// the behaviour changes.
private struct AlwaysSucceedsFactory<Model: Decodable & Sendable>: DataDecoderFactory, Sendable {
    let model: Model

    func dataDecoder<Output: Decodable>(for type: Output.Type) -> DataDecoder<Output> {
        guard let result = model as? Output else {
            return Convert { _ in
                .failure(.dataCorrupted(.init(
                    codingPath: [],
                    debugDescription: "AlwaysSucceedsFactory: unexpected decode type '\(type)'"
                )))
            }
        }
        return Convert { _ in .success(result) }
    }
}

#endif
