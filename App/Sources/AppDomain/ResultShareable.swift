import Foundation
import UniformTypeIdentifiers

#if canImport(CoreTransferable)
import CoreTransferable

/// Transferable wrapper for PDF data — carries .pdf UTType.
public struct PDFShareable: Transferable, Sendable, Equatable {
    public let data: Data
    public let filename: String

    public init(data: Data, filename: String) {
        self.data = data
        self.filename = filename
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { $0.data }
            .suggestedFileName { $0.filename }
    }
}

/// Transferable wrapper for CSV data — carries .commaSeparatedText UTType.
public struct CSVShareable: Transferable, Sendable, Equatable {
    public let data: Data
    public let filename: String

    public init(data: Data, filename: String) {
        self.data = data
        self.filename = filename
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { $0.data }
            .suggestedFileName { $0.filename }
    }
}
#endif

/// Input bundle passed to the CSV generator and PDF renderer.
public struct CalculatorExportData: Sendable {
    public let documentName: String
    public let lingo: FieldLingo
    public let compartmentNames: [String]
    public let rows: [(day: Double, values: [Double])]

    public init(documentName: String,
                lingo: FieldLingo,
                compartmentNames: [String],
                rows: [(day: Double, values: [Double])]) {
        self.documentName    = documentName
        self.lingo           = lingo
        self.compartmentNames = compartmentNames
        self.rows            = rows
    }
}
