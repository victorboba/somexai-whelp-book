import XCTest
@testable import WhelpBook

/// The due window, and the refusal to print a single confident date from a tie.
final class GestationTests: XCTestCase {
    private let calendar = Calendar.current

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000)))!
    }

    private func days(from: Date, to: Date) -> Int {
        calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    func testNothingToCountFromMeansNoWindow() {
        XCTAssertNil(Gestation.window(ovulation: nil, firstMating: nil, lastMating: nil))
    }

    func testOvulationGivesASixtyThreeDayLikelyDate() {
        let window = Gestation.window(ovulation: day(0), firstMating: nil, lastMating: nil)
        XCTAssertNotNil(window)
        XCTAssertEqual(window?.likely, day(63))
        XCTAssertEqual(window?.earliest, day(62))
        XCTAssertEqual(window?.latest, day(64))
        XCTAssertEqual(window?.countedFrom, "ovulation")
        XCTAssertEqual(window?.spanInDays, 2)
    }

    func testOvulationBeatsMatingDatesWhenBothArePresent() {
        let window = Gestation.window(ovulation: day(0), firstMating: day(-10), lastMating: day(-8))
        XCTAssertEqual(window?.countedFrom, "ovulation")
        XCTAssertEqual(window?.likely, day(63))
    }

    func testMatingsOnlyGiveAWiderWindow() {
        let window = Gestation.window(ovulation: nil, firstMating: day(0), lastMating: day(2))
        XCTAssertEqual(window?.earliest, day(58))
        XCTAssertEqual(window?.latest, day(70))
        XCTAssertEqual(window?.likely, day(65))
        XCTAssertEqual(window?.countedFrom, "the matings")
    }

    func testASingleMatingStandsInForBoth() {
        let fromFirst = Gestation.window(ovulation: nil, firstMating: day(0), lastMating: nil)
        let fromLast = Gestation.window(ovulation: nil, firstMating: nil, lastMating: day(0))
        XCTAssertEqual(fromFirst, fromLast)
        XCTAssertEqual(fromFirst?.earliest, day(58))
        XCTAssertEqual(fromFirst?.latest, day(68))
    }

    func testMatingDatesEnteredBackwardsStillProduceASaneWindow() {
        let window = Gestation.window(ovulation: nil, firstMating: day(5), lastMating: day(0))
        XCTAssertEqual(window?.earliest, day(58))
        XCTAssertEqual(window?.latest, day(73))
        XCTAssertTrue((window?.earliest ?? .now) <= (window?.likely ?? .now))
        XCTAssertTrue((window?.likely ?? .now) <= (window?.latest ?? .now))
    }

    func testLikelyDateAlwaysSitsInsideItsOwnWindow() {
        // Matings twelve days apart push 63-from-last past the window's own latest bound.
        let window = Gestation.window(ovulation: nil, firstMating: day(0), lastMating: day(30))
        XCTAssertNotNil(window)
        XCTAssertTrue(window!.contains(window!.likely))
    }

    func testTheWindowKnowsWhatFallsInsideIt() {
        let window = Gestation.window(ovulation: day(0), firstMating: nil, lastMating: nil)!
        XCTAssertTrue(window.contains(day(62)))
        XCTAssertTrue(window.contains(day(64)))
        XCTAssertFalse(window.contains(day(61)))
        XCTAssertFalse(window.contains(day(65)))
    }

    func testMilestonesCountFromOvulationWhenItIsKnown() {
        let milestones = Gestation.milestones(ovulation: day(0), firstMating: day(-5))
        XCTAssertFalse(milestones.isEmpty)
        let check = milestones.first { $0.day == 28 }
        XCTAssertEqual(check?.date, day(28))
    }

    func testMilestonesFallBackToTheFirstMating() {
        let milestones = Gestation.milestones(ovulation: nil, firstMating: day(0))
        XCTAssertEqual(milestones.first { $0.day == 45 }?.date, day(45))
    }

    func testMilestonesAreEmptyWithNoAnchor() {
        XCTAssertTrue(Gestation.milestones(ovulation: nil, firstMating: nil).isEmpty)
    }

    func testNextMilestoneSkipsThePastOnes() {
        let next = Gestation.nextMilestone(ovulation: day(0), firstMating: nil, now: day(46))
        XCTAssertEqual(next?.day, 55)
    }

    func testNoNextMilestoneOnceTheyHaveAllPassed() {
        XCTAssertNil(Gestation.nextMilestone(ovulation: day(0), firstMating: nil, now: day(100)))
    }

    func testDayOfGestationCountsFromTheAnchor() {
        XCTAssertEqual(Gestation.dayOfGestation(ovulation: day(0), firstMating: nil, now: day(30)), 30)
        XCTAssertEqual(Gestation.dayOfGestation(ovulation: nil, firstMating: day(0), now: day(30)), 30)
        XCTAssertNil(Gestation.dayOfGestation(ovulation: nil, firstMating: nil, now: day(30)))
    }

    func testDayZeroIsDayZeroAndNotOne() {
        XCTAssertEqual(Gestation.dayOfGestation(ovulation: day(0), firstMating: nil, now: day(0)), 0)
    }
}
