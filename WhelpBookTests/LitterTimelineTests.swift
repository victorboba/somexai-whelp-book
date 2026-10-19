import XCTest
@testable import WhelpBook

/// The spine. Every stage transition, including the ones that only happen once a year.
final class LitterTimelineTests: XCTestCase {
    private let calendar = Calendar.current

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000)))!
    }

    private func status(_ facts: LitterFacts, now offset: Int = 0) -> LitterStatus {
        LitterTimeline.status(facts, now: day(offset))
    }

    func testAnEmptyLitterAsksForTheSeasonStart() {
        let result = status(LitterFacts())
        XCTAssertEqual(result.stage, .season)
        XCTAssertTrue(result.nextTitle.contains("season"), result.nextTitle)
        XCTAssertTrue(result.completed.isEmpty)
    }

    func testASeasonOnItsOwnIsTheSeasonStage() {
        let result = status(LitterFacts(seasonStart: day(-3)), now: 0)
        XCTAssertEqual(result.stage, .season)
        XCTAssertEqual(result.headline, "Day 3 of her season")
        XCTAssertTrue(result.completed.contains(.season))
    }

    func testRecentMatingsAreTheBredStage() {
        let facts = LitterFacts(seasonStart: day(-14), firstMating: day(-5), lastMating: day(-3))
        let result = status(facts)
        XCTAssertEqual(result.stage, .bred)
        XCTAssertTrue(result.completed.contains(.bred))
        XCTAssertFalse(result.completed.contains(.expecting))
    }

    func testAfterTwentyEightDaysSheIsExpecting() {
        let facts = LitterFacts(firstMating: day(-28), lastMating: day(-28))
        let result = status(facts)
        XCTAssertEqual(result.stage, .expecting)
        XCTAssertTrue(result.completed.contains(.expecting))
    }

    func testTheBoundaryAtDayTwentySeven() {
        XCTAssertEqual(status(LitterFacts(firstMating: day(-27), lastMating: day(-27))).stage, .bred)
    }

    func testTheWindowOpeningSwitchesToWhelping() {
        // Ovulation 62 days ago: the earliest day of the window is today.
        let facts = LitterFacts(ovulation: day(-62))
        let result = status(facts)
        XCTAssertEqual(result.stage, .whelping)
        XCTAssertTrue(result.nextTitle.contains("whelping log"), result.nextTitle)
    }

    func testTheDayBeforeTheWindowIsStillExpecting() {
        XCTAssertEqual(status(LitterFacts(ovulation: day(-61))).stage, .expecting)
    }

    func testPastTheWindowSaysSoRatherThanGoingQuiet() {
        let result = status(LitterFacts(ovulation: day(-70)))
        XCTAssertEqual(result.stage, .whelping)
        XCTAssertTrue(result.headline.contains("Past the window"), result.headline)
        XCTAssertTrue(result.headline.contains("6"), result.headline)
    }

    func testTheNightItselfStaysOnWhelping() {
        let facts = LitterFacts(ovulation: day(-63), whelpedAt: day(0), puppyCount: 3)
        let result = status(facts, now: 0)
        XCTAssertEqual(result.stage, .whelping)
        XCTAssertEqual(result.headline, "3 puppies so far")
    }

    func testOnePuppyIsSingular() {
        let facts = LitterFacts(whelpedAt: day(0), puppyCount: 1)
        XCTAssertEqual(status(facts, now: 0).headline, "1 puppy so far")
    }

    func testTheMorningAfterIsRaisingPuppies() {
        let facts = LitterFacts(whelpedAt: day(-1), puppyCount: 6)
        let result = status(facts)
        XCTAssertEqual(result.stage, .raising)
        XCTAssertEqual(result.nextTitle, "Today's weigh-in")
        XCTAssertTrue(result.headline.contains("6 puppies"), result.headline)
    }

    func testSevenWeeksInIsTheGoingHomeStage() {
        let facts = LitterFacts(whelpedAt: day(-49), puppyCount: 6, puppiesPlaced: 1)
        let result = status(facts)
        XCTAssertEqual(result.stage, .goingHome)
        XCTAssertTrue(result.headline.contains("5 of 6"), result.headline)
        XCTAssertTrue(result.completed.contains(.raising))
    }

    func testTheDayBeforeSevenWeeksIsStillRaising() {
        XCTAssertEqual(status(LitterFacts(whelpedAt: day(-48), puppyCount: 6)).stage, .raising)
    }

    func testAnEarlyGoHomeDatePullsTheHandoverWeekForward() {
        // Go-home date in five days: the handover week has already started even at three weeks old.
        let facts = LitterFacts(whelpedAt: day(-21), puppyCount: 5, goHomeDate: day(5))
        XCTAssertEqual(status(facts).stage, .goingHome)
    }

    func testEveryPuppyPlacedClosesTheLitter() {
        let facts = LitterFacts(whelpedAt: day(-60), puppyCount: 5, puppiesPlaced: 5)
        let result = status(facts)
        XCTAssertEqual(result.stage, .closed)
        XCTAssertTrue(result.headline.contains("All 5 placed"), result.headline)
        XCTAssertTrue(result.completed.contains(.goingHome))
    }

    func testAnEmptyLitterIsNotAccidentallyClosed() {
        // Zero puppies and zero placed must not satisfy "everybody has gone".
        let facts = LitterFacts(whelpedAt: day(-60), puppyCount: 0, puppiesPlaced: 0)
        XCTAssertNotEqual(status(facts).stage, .closed)
    }

    func testClosingByHandWorksEvenMidWay() {
        let facts = LitterFacts(whelpedAt: day(-10), puppyCount: 4, closedAt: day(-1))
        XCTAssertEqual(status(facts).stage, .closed)
    }

    func testStagesAreInTheOrderTheRailDrawsThem() {
        XCTAssertEqual(LitterStage.allCases.map(\.order), Array(0..<LitterStage.allCases.count))
        XCTAssertLessThan(LitterStage.season.order, LitterStage.bred.order)
        XCTAssertLessThan(LitterStage.whelping.order, LitterStage.raising.order)
        XCTAssertLessThan(LitterStage.goingHome.order, LitterStage.closed.order)
    }

    // MARK: Labels

    func testWeeksLabelSwitchesUnitsAtAFortnight() {
        XCTAssertEqual(LitterTimeline.weeksLabel(0), "0 days")
        XCTAssertEqual(LitterTimeline.weeksLabel(1), "1 day")
        XCTAssertEqual(LitterTimeline.weeksLabel(13), "13 days")
        XCTAssertEqual(LitterTimeline.weeksLabel(14), "2 weeks")
        XCTAssertEqual(LitterTimeline.weeksLabel(16), "2 weeks 2 days")
        XCTAssertEqual(LitterTimeline.weeksLabel(15), "2 weeks 1 day")
        XCTAssertEqual(LitterTimeline.weeksLabel(-4), "not born yet")
    }

    func testCountdownReadsLikeAPersonSpeaking() {
        XCTAssertEqual(LitterTimeline.countdown(to: day(0), from: day(0)), "today")
        XCTAssertEqual(LitterTimeline.countdown(to: day(1), from: day(0)), "tomorrow")
        XCTAssertEqual(LitterTimeline.countdown(to: day(-1), from: day(0)), "yesterday")
        XCTAssertEqual(LitterTimeline.countdown(to: day(9), from: day(0)), "in 9 days")
        XCTAssertEqual(LitterTimeline.countdown(to: day(-9), from: day(0)), "9 days ago")
    }
}
