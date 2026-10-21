import AppDomain
import Testing

/// Every unit the app offers goes to its canonical unit and back without loss, and a rate is
/// always the inverse of its time unit.
@Suite("Units")
struct UnitsTests {
    private let samples: [Double] = [0, 1e-6, 0.0627, 0.5, 1, 24, 48, 365.25, 1e9]

    @Test(arguments: TimeUnit.allCases)
    func timeRoundTrips(_ unit: TimeUnit) {
        for days in samples {
            #expect(isClose(unit.iso.reverseGet(unit.iso.get(days)), days))
            #expect(isClose(unit.iso.get(unit.iso.reverseGet(days)), days))
        }
    }

    @Test(arguments: TimeUnit.allCases)
    func rateRoundTrips(_ unit: TimeUnit) {
        let rate = RateUnit(per: unit)
        for perDay in samples {
            #expect(isClose(rate.iso.reverseGet(rate.iso.get(perDay)), perDay))
            #expect(isClose(rate.iso.get(rate.iso.reverseGet(perDay)), perDay))
        }
    }

    @Test func hoursAreADayOverTwentyFour() {
        #expect(TimeUnit.hours.iso.get(1) == 24)
        #expect(RateUnit(per: .hours).iso.get(48) == 2)
        #expect(RateUnit(per: .hours).iso.reverseGet(2) == 48)
        #expect(RateUnit(per: .hours).symbol == "h⁻¹")
    }

    /// A half-life and the rate that gives it agree in every unit: t½ · k = ln 2.
    @Test(arguments: TimeUnit.allCases)
    func halfLifeAndRateAgree(_ unit: TimeUnit) {
        let k = 0.5
        let halfLife = 0.693_147_180_559_945_3 / k
        #expect(isClose(unit.iso.get(halfLife) * RateUnit(per: unit).iso.get(k), 0.693_147_180_559_945_3))
    }

    @Test func fieldsPickTheirUnits() {
        #expect(ModelField.pharmacology.units.time == .hours)
        #expect(ModelField.pharmacology.units.rate == RateUnit(per: .hours))
        for field in ModelField.allCases where field != .pharmacology {
            #expect(field.units.time == .days)
        }
    }

    private func isClose(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) <= 1e-12 * max(1, abs(b))
    }
}
