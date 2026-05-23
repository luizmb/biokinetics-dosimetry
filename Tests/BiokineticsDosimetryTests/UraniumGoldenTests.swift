import XCTest
import XMLCoder
@testable import BiokineticsDosimetry

final class UraniumGoldenTests: XCTestCase {
    private struct Golden: Decodable {
        let intakeCompartmentId: String
        let fraction: Double
        let halfLife: Double
        let step: Int
        let final: Int
        let compartmentIds: [String]
        let times: [Int]
        let rows: [[Double]]
    }

    func testSwiftBirchallMatchesCSharpReference() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_GOLDEN"] != nil,
            "Slow (~220s). Run with `RUN_GOLDEN=1 swift test` or generate a fresh fixture from ../ipen-validator first."
        )

        let goldenURL = try XCTUnwrap(Bundle.module.url(forResource: "uranium_birchall_golden", withExtension: "json"))
        let golden = try JSONDecoder().decode(Golden.self, from: Data(contentsOf: goldenURL))

        let xmlURL = try XCTUnwrap(Bundle.module.url(forResource: "Uranium", withExtension: "xml"))
        let xmlData = try Data(contentsOf: xmlURL)
        let loaded = try loadCompartmentalModel(using: XMLDecoder())(xmlData).get()

        XCTAssertEqual(loaded.compartments.map(\.id), golden.compartmentIds,
                       "Swift loader and C# loader must produce compartments in the same order")

        let model = loaded.updatingCompartment(id: golden.intakeCompartmentId) {
            $0.with(intake: true, fraction: golden.fraction)
        }
        let calculator = InternalDosimetryCalculator(step: golden.step, halfLife: golden.halfLife, final: golden.final)
        let swiftRows = await calculator.calculate(model: model).run()

        XCTAssertEqual(swiftRows.count, golden.rows.count, "row count mismatch")

        let tolerance = 1e-12
        for (rowIndex, (swiftRow, goldenRow)) in zip(swiftRows, golden.rows).enumerated() {
            XCTAssertEqual(swiftRow.count, goldenRow.count, "row \(rowIndex) length mismatch")
            for (col, (swiftValue, goldenValue)) in zip(swiftRow, goldenRow).enumerated() {
                XCTAssertEqual(
                    swiftValue, goldenValue, accuracy: tolerance,
                    "row \(rowIndex) (t=\(golden.times[rowIndex])) compartment \(col) (\(golden.compartmentIds[col]))"
                )
            }
        }
    }
}
