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
    public let solver: @Sendable (BiokineticsSimulationPlan, CompartmentalModel) -> DeferredTask<[[Double]]>
    public let generateCSV: @Sendable (CalculatorExportData) -> DeferredTask<Result<Data, Error>>
    public let renderPDF:   @Sendable (CalculatorExportData) -> DeferredTask<Result<Data, Error>>
    public let saveDocument: @Sendable (ModelDocument) -> Result<Void, PersistenceError>
    public let loadAllDocuments: @Sendable () -> Result<[ModelDocument], PersistenceError>
    public let deleteDocument: @Sendable (UUID) -> Result<Void, PersistenceError>

    public init(
        xmlDecoder:  Sendable & DataDecoderFactory,
        jsonDecoder: Sendable & DataDecoderFactory,
        solver: @escaping @Sendable (BiokineticsSimulationPlan, CompartmentalModel) -> DeferredTask<[[Double]]>,
        generateCSV: @escaping @Sendable (CalculatorExportData) -> DeferredTask<Result<Data, Error>>,
        renderPDF:   @escaping @Sendable (CalculatorExportData) -> DeferredTask<Result<Data, Error>>,
        saveDocument: @escaping @Sendable (ModelDocument) -> Result<Void, PersistenceError>,
        loadAllDocuments: @escaping @Sendable () -> Result<[ModelDocument], PersistenceError>,
        deleteDocument: @escaping @Sendable (UUID) -> Result<Void, PersistenceError>
    ) {
        self.xmlDecoder  = xmlDecoder
        self.jsonDecoder = jsonDecoder
        self.solver      = solver
        self.generateCSV = generateCSV
        self.renderPDF   = renderPDF
        self.saveDocument = saveDocument
        self.loadAllDocuments = loadAllDocuments
        self.deleteDocument = deleteDocument
    }
}
