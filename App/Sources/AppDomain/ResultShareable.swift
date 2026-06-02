import Foundation
import UniformTypeIdentifiers

#if canImport(CoreTransferable)
import CoreTransferable

// MARK: - Lazy-generating Transferable types

/// Carries the data needed to produce a CSV and generates it lazily when
/// the system share sheet requests the file. No intermediate state needed.
public struct CSVExportInput: Transferable, Sendable, Equatable {
    public let documentName: String
    public let lingo: FieldLingo
    public let compartmentNames: [String]
    public let rows: [(day: Double, values: [Double])]

    public init(documentName: String, lingo: FieldLingo,
                compartmentNames: [String], rows: [(day: Double, values: [Double])]) {
        self.documentName     = documentName
        self.lingo            = lingo
        self.compartmentNames = compartmentNames
        self.rows             = rows
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { input in
            var lines: [String] = []
            let header = (["Time (\(input.lingo.timeUnit.label))"] + input.compartmentNames)
                .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
                .joined(separator: ",")
            lines.append(header)
            for row in input.rows {
                let time   = String(format: "%.6g", row.day)
                let values = row.values.map { String(format: "%.9e", $0) }
                lines.append(([time] + values).joined(separator: ","))
            }
            guard let data = lines.joined(separator: "\r\n").data(using: .utf8) else {
                throw CocoaError(.fileWriteUnknown)
            }
            return data
        }
        .suggestedFileName { $0.documentName + ".csv" }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.documentName == rhs.documentName &&
        lhs.compartmentNames == rhs.compartmentNames &&
        lhs.rows.count == rhs.rows.count
    }
}

/// Carries the data needed to produce a PDF and generates it lazily.
public struct PDFExportInput: Transferable, Sendable, Equatable {
    public let documentName: String
    public let lingo: FieldLingo
    public let compartmentNames: [String]
    public let rows: [(day: Double, values: [Double])]

    public init(documentName: String, lingo: FieldLingo,
                compartmentNames: [String], rows: [(day: Double, values: [Double])]) {
        self.documentName     = documentName
        self.lingo            = lingo
        self.compartmentNames = compartmentNames
        self.rows             = rows
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { input in
            try input.generatePDF()
        }
        .suggestedFileName { $0.documentName + ".pdf" }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.documentName == rhs.documentName &&
        lhs.compartmentNames == rhs.compartmentNames &&
        lhs.rows.count == rhs.rows.count
    }
}

#endif

// MARK: - Input bundle for World-injected generators (kept for direct use)

public struct CalculatorExportData: Sendable {
    public let documentName: String
    public let lingo: FieldLingo
    public let compartmentNames: [String]
    public let rows: [(day: Double, values: [Double])]

    public init(documentName: String, lingo: FieldLingo,
                compartmentNames: [String], rows: [(day: Double, values: [Double])]) {
        self.documentName     = documentName
        self.lingo            = lingo
        self.compartmentNames = compartmentNames
        self.rows             = rows
    }
}
