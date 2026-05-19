import XCTest
import XMLCoder
@testable import MultiCompartmentModel

final class CompartmentalModelLoaderTests: XCTestCase {
    func testLoadsUraniumModelFromXML() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "Uranium", withExtension: "xml"),
            "Uranium.xml fixture missing"
        )
        let data = try Data(contentsOf: url)

        let model = try loadCompartmentalModel(using: XMLDecoder())(data).get()

        XCTAssertEqual(model.compartments.count, 19, "Uranium model has 19 compartments")
        XCTAssertEqual(model.compartments.first?.name, "Intermediate Turnover (ST1)")
        XCTAssertEqual(model.compartments.first?.follow, true)

        let plasma = model.compartments.first { $0.name == "Plasma" }
        XCTAssertNotNil(plasma)
        XCTAssertEqual(plasma?.id, "4")
        XCTAssertEqual(plasma?.follow, true)
        XCTAssertEqual(plasma?.dispose, false)

        let urine = model.compartments.first { $0.name == "Urine" }
        XCTAssertEqual(urine?.dispose, true)

        let plasmaToST0 = try XCTUnwrap(model.connections.first { $0.from == "2" && $0.to == "4" })
        XCTAssertEqual(plasmaToST0.rate, 8.32, accuracy: 1e-12)

        let st0ToPlasma = try XCTUnwrap(model.connections.first { $0.from == "4" && $0.to == "2" })
        XCTAssertEqual(st0ToPlasma.rate, 10.5, accuracy: 1e-12)

        let zeroRateConnections = model.connections.filter { $0.rate == 0 }
        XCTAssertTrue(zeroRateConnections.isEmpty, "Zero-rate connections should be filtered out")
    }

    func testRunsCalculatorOnUraniumWithPlasmaIntake() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Uranium", withExtension: "xml"))
        let data = try Data(contentsOf: url)
        let loaded = try loadCompartmentalModel(using: XMLDecoder())(data).get()

        let model = loaded.updatingCompartment(id: "4") { $0.with(intake: true, fraction: 1.0) }

        let halfLife = 4.5e9 * 365.0
        let calculator = InternalDosimetryCalculator(step: 1, halfLife: halfLife, final: 10)
        let result = calculator.calculate(model: model)

        XCTAssertEqual(result.count, 12, "stepCount+2 rows expected")
        XCTAssertEqual(result[0].count, 19, "n compartments")

        let plasmaIndex = try XCTUnwrap(model.compartments.firstIndex(where: { $0.id == "4" }))
        XCTAssertEqual(result[0][plasmaIndex], 1.0, accuracy: 1e-12, "All activity in Plasma at t=0")

        let totalAtT0 = result[0].reduce(0, +)
        XCTAssertEqual(totalAtT0, 1.0, accuracy: 1e-12, "Total activity = 1 at t=0")

        let plasmaT1 = result[1][plasmaIndex]
        XCTAssertGreaterThan(plasmaT1, 0)
        XCTAssertLessThan(plasmaT1, 1.0, "Plasma activity decreases as transfer kicks in")
    }
}
