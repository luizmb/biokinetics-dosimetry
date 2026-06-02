import AppDomain
import Foundation
import Solver
@preconcurrency import XMLCoder

// MARK: - World (live)

extension World {
    public static var real: Self {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return .init(
            xmlDecoder:  XMLDecoder(),
            jsonDecoder: decoder,
            newId:       { UUID() },
            solver:      { plan, model in Solver.solve(plan: plan, model: model) },
            generateCSV: generateCalculatorCSV,
            renderPDF:   renderCalculatorPDF,
            saveDocument: { doc in
                Result {
                    let dir = try biokineticsDocs()
                    let data = try encoder.encode(doc)
                    try data.write(to: dir.appendingPathComponent("\(doc.id).json"),
                                   options: .atomic)
                }
                .mapError { PersistenceError.fileSystemFailed($0.localizedDescription) }
            },
            loadAllDocuments: {
                Result<[ModelDocument], Error> {
                    let dir = try biokineticsDocs()
                    let urls = try FileManager.default
                        .contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                        .filter { $0.pathExtension == "json" }
                    var docs: [ModelDocument] = []
                    for url in urls {
                        let data = try Data(contentsOf: url)
                        if let doc = try? decoder.decode(ModelDocument.self, from: data) {
                            docs.append(doc)
                        }
                    }
                    return docs.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                }
                .mapError { PersistenceError.fileSystemFailed($0.localizedDescription) }
            },
            deleteDocument: { id in
                Result {
                    let file = try biokineticsDocs().appendingPathComponent("\(id).json")
                    guard FileManager.default.fileExists(atPath: file.path) else { return }
                    try FileManager.default.removeItem(at: file)
                }
                .mapError { PersistenceError.fileSystemFailed($0.localizedDescription) }
            }
        )
    }
}

// MARK: - Helpers

private func biokineticsDocs() throws -> URL {
    let docs = try FileManager.default.url(
        for: .documentDirectory, in: .userDomainMask,
        appropriateFor: nil, create: true
    )
    let dir = docs.appendingPathComponent("Biokinetics", isDirectory: true)
    try FileManager.default.createDirectory(at: dir,
                                             withIntermediateDirectories: true,
                                             attributes: nil)
    return dir
}
