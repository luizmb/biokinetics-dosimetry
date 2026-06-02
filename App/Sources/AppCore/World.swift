import AppDomain
import Core
import CoreFP
import Domain
import Foundation

// MARK: - World

/// App-level dependencies injected once at startup.
///
/// Features receive a narrow slice via `lift(environment:)` — nothing here leaks
/// concrete third-party types. Live construction lives in `World+Real.swift`.
public struct World: Sendable {
    public let xmlDecoder:  Sendable & DataDecoderFactory
    public let jsonDecoder: Sendable & DataDecoderFactory
    public let newId:        @Sendable () -> UUID
    public let formatDouble: @Sendable (Double, Int) -> String    // (value, decimalPlaces) — locale-aware
    public let parseDouble:  @Sendable (String) -> Double?        // locale-aware input parsing
    public let solver: @Sendable (BiokineticsSimulationPlan, CompartmentalModel) -> DeferredTask<Result<[[Double]], Error>>
    public let saveDocument: @Sendable (ModelDocument) -> Result<Void, PersistenceError>
    public let loadAllDocuments: @Sendable () -> Result<[ModelDocument], PersistenceError>
    public let deleteDocument: @Sendable (UUID) -> Result<Void, PersistenceError>

    public init(
        xmlDecoder:  Sendable & DataDecoderFactory,
        jsonDecoder: Sendable & DataDecoderFactory,
        newId:        @escaping @Sendable () -> UUID,
        formatDouble: @escaping @Sendable (Double, Int) -> String,
        parseDouble:  @escaping @Sendable (String) -> Double?,
        solver: @escaping @Sendable (BiokineticsSimulationPlan, CompartmentalModel) -> DeferredTask<Result<[[Double]], Error>>,
        saveDocument: @escaping @Sendable (ModelDocument) -> Result<Void, PersistenceError>,
        loadAllDocuments: @escaping @Sendable () -> Result<[ModelDocument], PersistenceError>,
        deleteDocument: @escaping @Sendable (UUID) -> Result<Void, PersistenceError>
    ) {
        self.xmlDecoder   = xmlDecoder
        self.jsonDecoder  = jsonDecoder
        self.newId        = newId
        self.formatDouble = formatDouble
        self.parseDouble  = parseDouble
        self.solver       = solver
        self.saveDocument = saveDocument
        self.loadAllDocuments = loadAllDocuments
        self.deleteDocument = deleteDocument
    }
}
