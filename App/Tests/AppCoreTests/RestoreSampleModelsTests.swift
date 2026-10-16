import AppDomain
import Domain
import Foundation
import HomeFeature
import SwiftRex
import SwiftRexTesting
import Testing

/// "Restore sample models" brings back exactly the samples that were deleted: an edited sample
/// keeps its id, so it stays as it is and is not duplicated.
@Suite("Restore sample models")
@MainActor
struct RestoreSampleModelsTests {
    /// A fixed id per sample key, as the app's own table has: FNV-1a over the key, twice.
    private let env: HomeFeature.Environment = {
        var env = HomeFeature.Environment.alwaysFails
        env.seedId = { key in
            func fnv(_ seed: UInt64) -> UInt64 {
                key.utf8.reduce(seed) { ($0 ^ UInt64($1)) &* 0x100_0000_01B3 }
            }
            let (a, b) = (fnv(0xCBF2_9CE4_8422_2325), fnv(0x84222325_CBF29CE4))
            let bytes = (0 ..< 8).map { UInt8(truncatingIfNeeded: a >> ($0 * 8)) } + (0 ..< 8).map { UInt8(truncatingIfNeeded: b >> ($0 * 8)) }
            return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                               bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
        }
        return env
    }()
    private var samples: [ModelDocument] { SeedDocuments.samples(idFor: env.seedId) }

    /// Home with every sample but the first two deleted, the second one edited, plus a user's own model.
    private func homeAfterDeletesAndEdits() -> (HomeFeature.State, edited: ModelDocument, own: ModelDocument) {
        var edited = samples[1]
        edited.name = "My edited sample"
        let own = ModelDocument.validation
        var state = HomeFeature.initialState(with: ())
        state.documents = .loaded([samples[0], edited, own])
        return (state, edited, own)
    }

    @Test func theSamplesAllHaveDistinctIds() {
        #expect(Set(samples.map(\.id)).count == samples.count)
    }

    @Test func onlyTheDeletedSamplesAreMissing() {
        let (state, edited, own) = homeAfterDeletesAndEdits()
        let missing = SeedDocuments.missing(from: state.documents.loaded ?? [], idFor: env.seedId)
        #expect(missing.count == samples.count - 2)
        #expect(!missing.contains { $0.id == samples[0].id || $0.id == edited.id || $0.id == own.id })
    }

    @Test func theButtonCountsWhatItWouldRestore() {
        let (state, _, _) = homeAfterDeletesAndEdits()
        #expect(HomeFeature.mapState.runReader(env)(state).restorableSampleCount == samples.count - 2)
        var complete = state
        complete.documents = .loaded(samples)
        #expect(HomeFeature.mapState.runReader(env)(complete).restorableSampleCount == 0)
    }

    @Test func restoringAddsTheMissingKeepsTheEditedAndClosesTheSheet() async {
        var (initial, edited, own) = homeAfterDeletesAndEdits()
        initial.isCreationSheetOpen = true
        let store = TestStore(initial: initial, behavior: HomeFeature.behavior(), environment: env)
        store.dispatch(.restoreSampleModels) { _ in }
        await store.runEffects()
        store.receive(HomeFeature.Action.prism.sampleModelsRestored) { _, state in
            state.documents = .loaded([samples[0], edited, own] + samples.dropFirst(2))
            state.isCreationSheetOpen = false
        }
        await store.runEffects()
        #expect(store.state.documents.loaded?.first { $0.id == edited.id }?.name == "My edited sample")
        #expect(store.state.documents.loaded?.count == samples.count + 1)
    }
}
