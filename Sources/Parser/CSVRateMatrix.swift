import Domain
import Foundation

/// Parses a transfer-rate matrix CSV into a `CompartmentalModel`.
///
/// **Expected format** (first row = header, first column = row label):
///
/// ```
/// Name,Plasma,Tissue,Urine
/// Plasma,,0.5,0.2
/// Tissue,0.3,,
/// Urine,,,
/// ```
///
/// - `matrix[i][j]` is the transfer rate (day⁻¹) *from* row-i compartment *to* col-j compartment.
/// - Empty cells and zero values produce no connection.
/// - The first header cell is ignored (use any label or leave blank).
/// - Intake and sink compartments are detected by topology (same heuristic as the IPEN XML importer).
public func parseCSVRateMatrix(data: Data) -> Result<CompartmentalModel, Error> {
    guard let text = String(data: data, encoding: .utf8)
                  ?? String(data: data, encoding: .isoLatin1) else {
        return .failure(CSVParseError.invalidEncoding)
    }

    let rows = text.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
        .filter { !$0.isEmpty }

    guard rows.count >= 2 else { return .failure(CSVParseError.tooFewRows) }

    let headerCells = csvFields(rows[0])
    let names = headerCells.dropFirst()
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

    guard !names.isEmpty else { return .failure(CSVParseError.noCompartments) }

    let ids = names.indices.map { "c\($0)" }
    let nameToId = Dictionary(uniqueKeysWithValues: zip(names, ids))

    var connections: [CompartmentConnection] = []
    for row in rows.dropFirst() {
        let cells = csvFields(row)
        guard let fromName = cells.first?.trimmingCharacters(in: .whitespaces),
              let fromId = nameToId[fromName] else { continue }
        for (colIdx, cell) in cells.dropFirst().enumerated() {
            guard colIdx < ids.count else { break }
            let toId = ids[colIdx]
            guard fromId != toId else { continue }
            if let rate = Double(cell.trimmingCharacters(in: .whitespaces)), rate > 0 {
                connections.append(CompartmentConnection(from: fromId, to: toId, rate: rate))
            }
        }
    }

    let destIds   = Set(connections.map(\.to))
    let sourceIds = Set(connections.map(\.from))

    let noInbound = ids.filter { !destIds.contains($0) }
    let intakeIds: Set<String> = noInbound.isEmpty
        ? {
            let outDegree = Dictionary(grouping: connections, by: \.from).mapValues(\.count)
            let maxDeg = outDegree.values.max() ?? 0
            return Set(ids.filter { (outDegree[$0] ?? 0) == maxDeg }.prefix(1))
        }()
        : Set(noInbound)

    let sinkIds = Set(ids.filter { !sourceIds.contains($0) && !intakeIds.contains($0) })
    let equalFraction = intakeIds.isEmpty ? 0.0 : 1.0 / Double(intakeIds.count)

    let nuclide = Nuclide(id: "n0", name: "Imported", halfLife: 0)
    let compartments = zip(names, ids).map { name, id in
        Compartment(
            id: id, nuclideId: "n0", name: name, follow: true,
            intake: intakeIds.contains(id),
            dispose: sinkIds.contains(id),
            fraction: intakeIds.contains(id) ? equalFraction : 0
        )
    }

    return .success(CompartmentalModel(nuclides: [nuclide], compartments: compartments, connections: connections))
}

// MARK: - Error

public enum CSVParseError: LocalizedError {
    case invalidEncoding
    case tooFewRows
    case noCompartments

    public var errorDescription: String? {
        switch self {
        case .invalidEncoding:  "CSV file could not be read as UTF-8 or Latin-1 text."
        case .tooFewRows:       "CSV must have at least a header row and one data row."
        case .noCompartments:   "No compartment names found in the CSV header row."
        }
    }
}

// MARK: - Helpers

private func csvFields(_ row: String) -> [String] {
    var fields: [String] = []
    var current = ""
    var inQuotes = false
    for ch in row {
        switch ch {
        case "\"": inQuotes.toggle()
        case "," where !inQuotes:
            fields.append(current)
            current = ""
        default:
            current.append(ch)
        }
    }
    fields.append(current)
    return fields
}
