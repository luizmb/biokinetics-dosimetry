import AppDomain
import ReactiveConcurrency
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
            newId:        { UUID() },
            seedId:       liveSeedId,
            formatDouble: liveFormatDouble,
            parseDouble:  liveParseDouble,
            solver:       { plan, model in Solver.solve(plan: plan, model: model).map(Result.success).eraseToThrowingPublisher() },
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

// MARK: - Stable seed document UUIDs — the ONLY place UUID(uuidString:) may appear

private let liveSeedIds: [String: UUID] = {
    func u(_ s: String) -> UUID { UUID(uuidString: s)! }
    return [
        // ModelDocument.empty sentinel
        "empty":                      u("00000000-0000-0000-0000-000000000000"),
        // Generic seeds
        "generic.2comp.pk":           u("00000001-0000-0000-0000-000000000001"),
        "generic.codeine.morphine":   u("00000001-0000-0000-0000-000000000002"),
        "generic.food.chain":         u("00000001-0000-0000-0000-000000000003"),
        "generic.2comp":              u("00000001-0000-0000-0000-000000000004"),
        // ICRP original 5
        "icrp.u234.type.s":           u("00000002-0000-0000-0000-000000000015"),
        "icrp.h3":                    u("00000002-0000-0000-0000-000000000011"),
        "icrp.cs137":                 u("00000002-0000-0000-0000-000000000012"),
        "icrp.i131":                  u("00000002-0000-0000-0000-000000000013"),
        "icrp.sr90":                  u("00000002-0000-0000-0000-000000000014"),
        // Nuclear chain
        "icrp.u238.chain":            u("00000003-0000-0000-0000-000000000001"),
        // Extended nuclear
        "icrp.pu239":                 u("00000004-0000-0000-0000-000000000001"),
        "icrp.am241":                 u("00000004-0000-0000-0000-000000000002"),
        "icrp.co60":                  u("00000004-0000-0000-0000-000000000003"),
        "icrp.tc99m":                 u("00000004-0000-0000-0000-000000000004"),
        "icrp.th232":                 u("00000004-0000-0000-0000-000000000005"),
        "icrp.pb210.po210":           u("00000004-0000-0000-0000-000000000006"),
        // Pharmacology
        "pk.1comp.oral":              u("00000005-0000-0000-0000-000000000001"),
        "pk.2comp.oral":              u("00000005-0000-0000-0000-000000000002"),
        "pk.digoxin":                 u("00000005-0000-0000-0000-000000000003"),
        // Toxicology
        "tox.lead.rabinowitz":        u("00000006-0000-0000-0000-000000000001"),
        "tox.methylmercury":          u("00000006-0000-0000-0000-000000000002"),
        "tox.cadmium":                u("00000006-0000-0000-0000-000000000003"),
        // Test fixtures (#if DEBUG)
        "fixture.iodo131":            u("000000f1-0000-0000-0000-000000000001"),
        "fixture.validation":         u("000000f1-0000-0000-0000-000000000002"),
        "fixture.multi.nuclide":      u("000000f1-0000-0000-0000-000000000004"),
    ]
}()

private let liveSeedId: @Sendable (String) -> UUID = { key in
    liveSeedIds[key] ?? UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!
}

// MARK: - Locale-aware number helpers

private let liveFormatDouble: @Sendable (Double, Int) -> String = { value, dp in
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = dp
    f.maximumFractionDigits = dp
    return f.string(from: NSNumber(value: value)) ?? String(value)
}

private let liveParseDouble: @Sendable (String) -> Double? = { text in
    let f = NumberFormatter()
    f.numberStyle = .decimal
    return f.number(from: text.trimmingCharacters(in: .whitespaces))?.doubleValue
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
