import XCTest
@testable import MultiCompartmentModel

final class AnalyticDecayTests: XCTestCase {
    private let tolerance = 1e-9

    func testTwoCompartmentTransferNoDecay() {
        let k = 0.1
        let model = CompartmentalModel(
            compartments: [
                Compartment(id: "a", name: "a", follow: false, intake: true, dispose: false, fraction: 1.0),
                Compartment(id: "b", name: "b", follow: false, intake: false, dispose: false, fraction: 0)
            ],
            connections: [
                CompartmentConnection(from: "a", to: "b", rate: k)
            ]
        )

        let result = InternalDosimetryCalculator(step: 1, halfLife: 0, final: 50).calculate(model: model)

        for t in [0, 1, 5, 10, 25, 50] {
            let aExpected = exp(-k * Double(t))
            let bExpected = 1 - aExpected
            XCTAssertEqual(result[t][0], aExpected, accuracy: tolerance, "a at t=\(t)")
            XCTAssertEqual(result[t][1], bExpected, accuracy: tolerance, "b at t=\(t)")
        }
    }

    func testThreeCompartmentBatemanChain() {
        let k1 = 0.1
        let k2 = 0.05
        let model = CompartmentalModel(
            compartments: [
                Compartment(id: "a", name: "a", follow: false, intake: true, dispose: false, fraction: 1.0),
                Compartment(id: "b", name: "b", follow: false, intake: false, dispose: false, fraction: 0),
                Compartment(id: "c", name: "c", follow: false, intake: false, dispose: false, fraction: 0)
            ],
            connections: [
                CompartmentConnection(from: "a", to: "b", rate: k1),
                CompartmentConnection(from: "b", to: "c", rate: k2)
            ]
        )

        let result = InternalDosimetryCalculator(step: 1, halfLife: 0, final: 100).calculate(model: model)

        for t in [0, 1, 5, 10, 25, 50, 100] {
            let tD = Double(t)
            let aExpected = exp(-k1 * tD)
            let bExpected = k1 / (k2 - k1) * (exp(-k1 * tD) - exp(-k2 * tD))
            let cExpected = 1 - aExpected - bExpected
            XCTAssertEqual(result[t][0], aExpected, accuracy: tolerance, "a at t=\(t)")
            XCTAssertEqual(result[t][1], bExpected, accuracy: tolerance, "b at t=\(t)")
            XCTAssertEqual(result[t][2], cExpected, accuracy: tolerance, "c at t=\(t)")
        }
    }

    func testSingleCompartmentRadioactiveDecay() {
        let halfLife = 10.0
        let model = CompartmentalModel(
            compartments: [
                Compartment(id: "a", name: "a", follow: false, intake: true, dispose: false, fraction: 1.0)
            ],
            connections: []
        )

        let result = InternalDosimetryCalculator(step: 1, halfLife: halfLife, final: 50).calculate(model: model)

        let lambda = log(2) / halfLife
        for t in [0, 1, 5, 10, 20, 50] {
            let expected = exp(-lambda * Double(t))
            XCTAssertEqual(result[t][0], expected, accuracy: tolerance, "a at t=\(t)")
        }
    }
}
