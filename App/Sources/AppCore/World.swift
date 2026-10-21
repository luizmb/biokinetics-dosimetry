import AppDomain
import Core
import CoreFP
import ReactiveConcurrency
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
    public let seedId:       @Sendable (String) -> UUID  // stable UUID for a named seed slot
    public let formatDouble: @Sendable (Double, Int) -> String    // (value, decimalPlaces) — locale-aware
    public let parseDouble:  @Sendable (String) -> Double?        // locale-aware input parsing
    public let formatScientific: @Sendable (Double, Int) -> String  // (value, mantissa decimals) — 1.23e-05
    public let formatInteger:    @Sendable (Int) -> String
    public let formatSignificant: @Sendable (Double) -> String      // up to four significant digits
    /// The screen's traits, seeded on subscribe and followed: the app keeps them in state, and views
    /// get what their projection makes of them, never by asking.
    public let deviceTraits: @Sendable () -> Publisher<DeviceTraits, Never>
    public let solver: @Sendable (BiokineticsSimulationPlan, CompartmentalModel) -> Publisher<[[Double]], Error>
    public let saveDocument: @Sendable (ModelDocument) -> Result<Void, PersistenceError>
    public let loadAllDocuments: @Sendable () -> Result<[ModelDocument], PersistenceError>
    public let deleteDocument: @Sendable (UUID) -> Result<Void, PersistenceError>

    public init(
        xmlDecoder:  Sendable & DataDecoderFactory,
        jsonDecoder: Sendable & DataDecoderFactory,
        newId:        @escaping @Sendable () -> UUID,
        seedId:       @escaping @Sendable (String) -> UUID,
        formatDouble: @escaping @Sendable (Double, Int) -> String,
        parseDouble:  @escaping @Sendable (String) -> Double?,
        formatScientific: @escaping @Sendable (Double, Int) -> String,
        formatInteger: @escaping @Sendable (Int) -> String,
        formatSignificant: @escaping @Sendable (Double) -> String,
        deviceTraits: @escaping @Sendable () -> Publisher<DeviceTraits, Never>,
        solver: @escaping @Sendable (BiokineticsSimulationPlan, CompartmentalModel) -> Publisher<[[Double]], Error>,
        saveDocument: @escaping @Sendable (ModelDocument) -> Result<Void, PersistenceError>,
        loadAllDocuments: @escaping @Sendable () -> Result<[ModelDocument], PersistenceError>,
        deleteDocument: @escaping @Sendable (UUID) -> Result<Void, PersistenceError>
    ) {
        self.xmlDecoder   = xmlDecoder
        self.jsonDecoder  = jsonDecoder
        self.newId        = newId
        self.seedId       = seedId
        self.formatDouble = formatDouble
        self.parseDouble  = parseDouble
        self.formatScientific = formatScientific
        self.formatInteger = formatInteger
        self.formatSignificant = formatSignificant
        self.deviceTraits = deviceTraits
        self.solver       = solver
        self.saveDocument = saveDocument
        self.loadAllDocuments = loadAllDocuments
        self.deleteDocument = deleteDocument
    }
}
