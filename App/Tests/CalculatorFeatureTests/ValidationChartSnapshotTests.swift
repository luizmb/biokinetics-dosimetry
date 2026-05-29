import AppDomain
import CalculatorFeature
import Domain
import Solver
import SnapshotTesting
import SwiftRexArchitecture
import SwiftRexTesting
import Testing

// SwiftUI .image(layout:) strategy is only available on iOS/tvOS simulators.
#if os(iOS) || os(tvOS)
import SwiftUI

/// Snapshot tests for the DecayChartView rendered with **real solver output** from
/// the "Validacao" 3-compartment reference model (A→B⇌C).
///
/// The model topology and reference values are cross-validated against the original
/// C# SSID app via `ValidationModelTests` in the core test suite.
///
/// Model:  A --0.1--> B <--0.05-- C
///                    B ---0.2--> C
/// Intake: A = 1.0,  step = 1 d,  final = 50 d
@Suite("ValidationChart Snapshots")
@MainActor
struct ValidationChartSnapshotTests {

    private static let layout = SwiftUISnapshotLayout.fixed(width: 800, height: 500)

    // MARK: - Model builder

    private func validationModel(halfLife: Double) -> ModelDocument {
        let nuclide = Nuclide(id: "n0", name: "Validation", halfLife: halfLife)
        let model = CompartmentalModel(
            nuclides: [nuclide],
            compartments: [
                Compartment(id: "1", nuclideId: "n0", name: "A",
                            follow: true,  intake: true,  dispose: false, fraction: 1.0),
                Compartment(id: "2", nuclideId: "n0", name: "B",
                            follow: true,  intake: false, dispose: false, fraction: 0),
                Compartment(id: "3", nuclideId: "n0", name: "C",
                            follow: true,  intake: false, dispose: false, fraction: 0)
            ],
            connections: [
                CompartmentConnection(from: "1", to: "2", rate: 0.1),
                CompartmentConnection(from: "2", to: "3", rate: 0.2),
                CompartmentConnection(from: "3", to: "2", rate: 0.05)
            ]
        )
        return ModelDocument(name: "Validacao", model: model)
    }

    // MARK: - Snapshot helper

    private func snap<F: Feature>(
        _ feature: TestFeature<F>,
        named name: String,
        testName: String = #function,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async where F.Content: View {
        await feature.ignoringActions {
            assertSnapshot(
                of: feature.view,
                as: .image(layout: Self.layout),
                named: name,
                file: file,
                testName: testName,
                line: line
            )
        }
    }

    // MARK: - Tests

    /// Stable substance (halfLife = 0): material redistributes among compartments,
    /// total always ≈ 1.0.  C should dominate A+B at long times.
    ///
    /// Uses `.realBirchall` — results are verified to match the C# reference
    /// to within 1e-5 by `ValidationModelTests.testHalfLifeZero`.
    @Test func snapshotValidationChartHalfLifeZero() async {
        let doc = validationModel(halfLife: 0)
        var initial = CalculatorFeature.initialState()
        initial.document = doc
        initial.finalDay = 50
        initial.results = await Solver.solve(
            plan: BiokineticsSimulationPlan(step: 1, final: 50, solver: .birchall(composition: .perTime)),
            model: doc.model
        ).run()
        initial.visibleSeriesIds = Set(doc.model.compartments.filter(\.follow).map(\.id))
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: .alwaysFails)
        await snap(feature, named: "validation-hl0")
    }

    /// Radioactive decay (halfLife = 5 d): all compartments decline after peak,
    /// approaching zero by ~10 half-lives (50 d).
    ///
    /// Uses `.realBirchall` — results are verified to match the C# reference
    /// to within 1e-5 by `ValidationModelTests.testHalfLifeFiveDays`.
    @Test func snapshotValidationChartHalfLifeFive() async {
        let doc = validationModel(halfLife: 5)
        var initial = CalculatorFeature.initialState()
        initial.document = doc
        initial.finalDay = 50
        initial.results = await Solver.solve(
            plan: BiokineticsSimulationPlan(step: 1, final: 50, solver: .birchall(composition: .perTime)),
            model: doc.model
        ).run()
        initial.visibleSeriesIds = Set(doc.model.compartments.filter(\.follow).map(\.id))
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: .alwaysFails)
        await snap(feature, named: "validation-hl5")
    }
}
#endif
