import AppDomain
import ReactiveConcurrency
import DataStructure
import Foundation
import Solver
@preconcurrency import XMLCoder
#if os(iOS)
import UIKit
#endif

// MARK: - World (live)

extension World {
    #if os(iOS)
    /// The live world for the app's one window, made by the scene delegate that made the window: the
    /// screen's traits are that window's.
    @MainActor public static func real(window: UIWindow) -> Self {
        real(deviceTraits: { traits(of: window) })
    }
    #endif

    static func real(deviceTraits: @escaping @Sendable () -> Publisher<DeviceTraits, Never>) -> Self {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Identities from a `Gen`, run against the world's one generator (the system's
        // randomness), rather than `UUID()` wherever one is needed.
        let generator = GenRunner(seed: nil)
        let ids = Gen<AnyRandomNumberGenerator, UUID>.uuid()
        // The person's locale, read once here, at the boundary: every number the app writes or
        // reads goes through a function made from it here, and nothing below the world holds it.
        let locale = Locale.autoupdatingCurrent

        return .init(
            xmlDecoder:  XMLDecoder(),
            jsonDecoder: decoder,
            newId:        { generator(ids) },
            seedId:       liveSeedId,
            formatDouble: localeFormatDouble(locale),
            parseDouble:  localeParseDouble(locale),
            formatScientific: localeFormatScientific(locale),
            formatInteger: { $0.formatted(.number.locale(locale)) },
            formatSignificant: { $0.formatted(.number.precision(.significantDigits(1 ... 4)).locale(locale)) },
            deviceTraits: deviceTraits,
            solver:       { plan, model in Solver.solve(plan: plan, model: model).map { $0.mapError { $0 as Error } }.eraseToThrowingPublisher() },
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

private func localeFormatDouble(_ locale: Locale) -> @Sendable (Double, Int) -> String {
    { value, dp in
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = dp
        f.maximumFractionDigits = dp
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }
}

/// `value` in scientific notation, the mantissa with `places` decimals in the locale: 1.23e-05
/// (1,23e-05). Zero is 0.00e+00.
private func localeFormatScientific(_ locale: Locale) -> @Sendable (Double, Int) -> String {
    { value, places in
        guard value.isFinite else { return value.formatted(.number.locale(locale)) }
        let exponent = value == 0 ? 0 : Int(floor(log10(abs(value))))
        let mantissa = value == 0 ? 0 : value / pow(10, Double(exponent))
        let digits = String(abs(exponent))
        return mantissa.formatted(.number.precision(.fractionLength(places)).locale(locale))
            + "e" + (exponent < 0 ? "-" : "+") + String(repeating: "0", count: max(0, 2 - digits.count)) + digits
    }
}

private func localeParseDouble(_ locale: Locale) -> @Sendable (String) -> Double? {
    { text in
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        return f.number(from: text.trimmingCharacters(in: .whitespaces))?.doubleValue
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
