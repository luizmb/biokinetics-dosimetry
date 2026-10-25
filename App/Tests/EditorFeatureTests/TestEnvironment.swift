import DataStructure
import EditorFeature
import Foundation

extension EditorFeature.Environment {
    /// The editor's world for a test: identities from a `Gen` on a seeded generator (the same ids
    /// every run, a different one each time one is asked for), and numbers in a fixed format.
    static var test: Self {
        let ids = TestIDs(seed: 1)
        return test(newId: { ids.next() })
    }

    /// The same, with identities from `newId`.
    static func test(newId: @escaping @Sendable () -> UUID) -> Self {
        EditorFeature.Environment(
            newId: newId,
            formatDouble: { v, dp in String(format: "%.\(dp)f", v) },
            formatScientific: { v, dp in String(format: "%.\(dp)e", v) },
            formatInteger: { String($0) },
            formatSignificant: { String(format: "%.4g", $0) },
            parseDouble: { Double($0) }
        )
    }
}

/// Runs `Gen.uuid()` against a seeded generator: the test's own boundary, the one place its ids
/// are made.
///
/// `@unchecked Sendable` justification: the generator is mutable, and every read-modify-write of it
/// goes through `lock`.
final class TestIDs: @unchecked Sendable {
    private let lock = NSLock()
    private var rng: AnyRandomNumberGenerator

    init(seed: UInt64) {
        rng = AnyRandomNumberGenerator(SplitMix64(seed: seed))
    }

    func next() -> UUID {
        lock.withLock { Gen<AnyRandomNumberGenerator, UUID>.uuid()(&rng) }
    }
}
