import XCTest
@testable import WhelpBook

/// The interval maths. The whole point of it is that it refuses to guess, so most of these tests
/// are about what it does when there is not enough evidence.
final class HeatHistoryTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000)))!
    }

    func testNoSeasonsHasNoIntervals() {
        XCTAssertEqual(HeatHistory.intervals(starts: []), [])
        XCTAssertNil(HeatHistory.averageIntervalDays(starts: []))
        XCTAssertNil(HeatHistory.projectedNextStart(starts: []))
    }

    func testOneSeasonIsNotAnInterval() {
        let starts = [day(0)]
        XCTAssertEqual(HeatHistory.intervals(starts: starts), [])
        XCTAssertNil(HeatHistory.averageIntervalDays(starts: starts))
        XCTAssertNil(HeatHistory.projectedNextStart(starts: starts), "One season must never produce a projection")
    }

    func testTwoSeasonsGiveOneInterval() {
        let starts = [day(0), day(174)]
        XCTAssertEqual(HeatHistory.intervals(starts: starts), [174])
        XCTAssertEqual(HeatHistory.averageIntervalDays(starts: starts), 174)
    }

    func testInputOrderDoesNotMatter() {
        let forwards = [day(0), day(174), day(350)]
        let backwards = [day(350), day(0), day(174)]
        XCTAssertEqual(HeatHistory.intervals(starts: forwards), HeatHistory.intervals(starts: backwards))
        XCTAssertEqual(HeatHistory.projectedNextStart(starts: forwards),
                       HeatHistory.projectedNextStart(starts: backwards))
    }

    func testAverageRoundsToTheNearestDay() {
        // 170 and 175 average 172.5, which rounds to 173.
        let starts = [day(0), day(170), day(345)]
        XCTAssertEqual(HeatHistory.intervals(starts: starts), [170, 175])
        XCTAssertEqual(HeatHistory.averageIntervalDays(starts: starts), 173)
    }

    func testProjectionCountsFromTheLatestSeason() {
        let starts = [day(0), day(180)]
        let projected = HeatHistory.projectedNextStart(starts: starts)
        XCTAssertEqual(projected, day(360))
    }

    func testProjectionIsNotAnAssumedSixMonths() {
        // A four-month girl must get a four-month projection, not 182 days.
        let starts = [day(0), day(120), day(242)]
        let average = HeatHistory.averageIntervalDays(starts: starts)
        XCTAssertEqual(average, 121)
        XCTAssertNotEqual(average, 182)
    }

    func testDuplicateSeasonStartsProduceAZeroInterval() {
        let starts = [day(0), day(0)]
        XCTAssertEqual(HeatHistory.intervals(starts: starts), [0])
        XCTAssertEqual(HeatHistory.averageIntervalDays(starts: starts), 0)
    }

    func testSpreadNeedsTwoIntervals() {
        XCTAssertNil(HeatHistory.spreadInDays(starts: [day(0), day(180)]))
        XCTAssertEqual(HeatHistory.spreadInDays(starts: [day(0), day(160), day(360)]), 40)
    }

    func testSummaryMatchesTheEvidence() {
        XCTAssertTrue(HeatHistory.summary(starts: []).contains("No seasons recorded"))
        XCTAssertTrue(HeatHistory.summary(starts: [day(0)]).contains("One season recorded"))
        XCTAssertTrue(HeatHistory.summary(starts: [day(0), day(174)]).contains("174 days"))
        let steady = HeatHistory.summary(starts: [day(0), day(170), day(340)])
        XCTAssertTrue(steady.contains("Every interval has been 170 days"), steady)
        let varied = HeatHistory.summary(starts: [day(0), day(150), day(350)])
        XCTAssertTrue(varied.contains("ranging 150 to 200"), varied)
    }

    func testDaysUntilProjectedGoesNegativeWhenOverdue() {
        let starts = [day(-400), day(-220)]
        let days = HeatHistory.daysUntilProjected(starts: starts, now: day(0))
        XCTAssertEqual(days, -40)
    }
}
