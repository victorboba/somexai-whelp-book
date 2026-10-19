import XCTest
@testable import WhelpBook

/// Units, and the one flag the daily weigh-in exists to raise.
final class WeightMathTests: XCTestCase {
    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date(timeIntervalSince1970: 1_700_000_000))!
    }

    private func samples(_ values: [Double]) -> [WeightSample] {
        values.enumerated().map { WeightSample(date: day($0.offset), grams: $0.element) }
    }

    // MARK: Units

    func testOuncesAndGramsRoundTrip() {
        let grams = 453.59237
        XCTAssertEqual(WeightMath.ounces(fromGrams: grams), 16, accuracy: 0.0001)
        XCTAssertEqual(WeightMath.grams(fromOunces: 16), grams, accuracy: 0.0001)
    }

    func testBothUnitsAreShownTogether() {
        let label = WeightMath.bothUnits(454)
        XCTAssertTrue(label.contains("454 g"), label)
        XCTAssertTrue(label.contains("16.0 oz"), label)
    }

    func testChangeStringAlwaysCarriesItsSign() {
        XCTAssertEqual(WeightMath.changeString(42), "+42 g")
        XCTAssertEqual(WeightMath.changeString(-42), "-42 g")
        XCTAssertEqual(WeightMath.changeString(0), "0 g")
        XCTAssertEqual(WeightMath.changeString(0.4), "0 g")
    }

    func testParsingRejectsBlanksZeroAndNonsense() {
        XCTAssertNil(WeightMath.parse("", unit: .grams))
        XCTAssertNil(WeightMath.parse("   ", unit: .grams))
        XCTAssertNil(WeightMath.parse("0", unit: .grams), "Zero must not land on the growth curve")
        XCTAssertNil(WeightMath.parse("-20", unit: .grams))
        XCTAssertNil(WeightMath.parse("heavy", unit: .grams))
    }

    func testParsingConvertsOuncesToGrams() {
        XCTAssertEqual(WeightMath.parse("16", unit: .ounces) ?? 0, 453.59237, accuracy: 0.0001)
        XCTAssertEqual(WeightMath.parse("16", unit: .grams) ?? 0, 16, accuracy: 0.0001)
    }

    func testParsingAcceptsACommaDecimal() {
        XCTAssertEqual(WeightMath.parse("6,5", unit: .ounces) ?? 0,
                       WeightMath.grams(fromOunces: 6.5), accuracy: 0.0001)
    }

    // MARK: The flag

    func testNoConcernWithFewerThanTwoWeights() {
        XCTAssertNil(WeightMath.concern(for: []))
        XCTAssertNil(WeightMath.concern(for: samples([400])))
    }

    func testGainingIsNotAConcern() {
        XCTAssertNil(WeightMath.concern(for: samples([400, 450, 500])))
    }

    func testAWeightThatDroppedIsFlagged() {
        XCTAssertEqual(WeightMath.concern(for: samples([400, 450, 430])), .lost)
    }

    func testAWeightThatDidNotMoveIsFlagged() {
        XCTAssertEqual(WeightMath.concern(for: samples([400, 450, 450])), .noGain)
    }

    func testOnlyTheLastTwoWeightsDecideTheFlag() {
        // A dip in the middle that has since recovered is not the puppy that needs watching now.
        XCTAssertNil(WeightMath.concern(for: samples([400, 380, 460])))
    }

    func testScaleNoiseUnderOneGramCountsAsNoGain() {
        XCTAssertEqual(WeightMath.concern(for: samples([400, 400.4])), .noGain)
        XCTAssertNil(WeightMath.concern(for: samples([400, 401.5])))
    }

    func testOutOfOrderSamplesAreSortedBeforeComparing() {
        let unsorted = [WeightSample(date: day(2), grams: 430),
                        WeightSample(date: day(0), grams: 400),
                        WeightSample(date: day(1), grams: 450)]
        XCTAssertEqual(WeightMath.concern(for: unsorted), .lost)
        XCTAssertEqual(WeightMath.changeSincePrevious(unsorted) ?? 0, -20, accuracy: 0.001)
    }

    func testTheFlagWordingNeverDiagnoses() {
        for concern in [WeightMath.Concern.lost, .noGain] {
            let text = (concern.label + " " + concern.detail).lowercased()
            // "diagnose" (the verb) is forbidden; "diagnosis" (the noun) is not, because the required
            // disclaimer below is built from exactly that word ("not a diagnosis").
            for forbidden in ["fading", "diagnose", "illness", "sick", "infection", "treat", "dose", "vet immediately"] {
                XCTAssertFalse(text.contains(forbidden), "\(concern) says \"\(forbidden)\", which is a clinical claim this app must not make")
            }
            XCTAssertTrue(concern.detail.contains("not a diagnosis"))
        }
    }

    // MARK: Aggregates

    func testTotalGainAndAverageDailyGain() {
        let values = samples([400, 460, 520])
        XCTAssertEqual(WeightMath.totalGain(values) ?? 0, 120, accuracy: 0.001)
        XCTAssertEqual(WeightMath.averageDailyGain(values) ?? 0, 60, accuracy: 0.001)
    }

    func testAverageDailyGainIsNilWhenEverythingLandedOnOneDay() {
        let sameDay = [WeightSample(date: day(0), grams: 400), WeightSample(date: day(0), grams: 420)]
        XCTAssertNil(WeightMath.averageDailyGain(sameDay), "Dividing by zero days would invent a number")
    }

    func testAggregatesAreNilWithASingleSample() {
        XCTAssertNil(WeightMath.totalGain(samples([400])))
        XCTAssertNil(WeightMath.changeSincePrevious(samples([400])))
    }
}
