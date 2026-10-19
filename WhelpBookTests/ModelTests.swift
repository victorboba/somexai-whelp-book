import XCTest
import SwiftData
@testable import WhelpBook

/// The model layer: names that never come out blank, samples that include the birth weight, the
/// health schedule's dates, and the CloudKit shape the whole template depends on.
@MainActor
final class ModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Dam.self, HeatCycle.self, Litter.self, Puppy.self,
                             WeighIn.self, HealthTask.self, HealthGiven.self])
        container = try ModelContainer(for: schema,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
    }

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: .now))!
    }

    // MARK: Naming

    func testAPuppyAlwaysHasSomethingToCallIt() {
        let puppy = Puppy(birthOrder: 3)
        XCTAssertEqual(puppy.displayName, "Puppy 3")
        puppy.collar = "Blue"
        XCTAssertEqual(puppy.displayName, "Blue collar")
        puppy.name = "Scout"
        XCTAssertEqual(puppy.displayName, "Scout")
    }

    func testADamAlwaysHasSomethingToCallHer() {
        XCTAssertEqual(Dam().displayName, "Unnamed dam")
        XCTAssertEqual(Dam(name: "Juno").displayName, "Juno")
    }

    func testALitterFallsBackToThePairing() {
        let dam = Dam(name: "Juno")
        let litter = Litter(sireName: "Ridge")
        litter.dam = dam
        XCTAssertEqual(litter.displayName, "Juno x Ridge")
        litter.name = "Spring litter"
        XCTAssertEqual(litter.displayName, "Spring litter")
    }

    func testALitterWithNoStudStillNamesItself() {
        let dam = Dam(name: "Juno")
        let litter = Litter()
        litter.dam = dam
        XCTAssertEqual(litter.displayName, "Juno")
        XCTAssertEqual(Litter().pairing, "Dam not set")
    }

    // MARK: Weight samples

    func testBirthWeightIsTheFirstPointOnTheCurve() {
        let puppy = Puppy(birthOrder: 1, bornAt: day(-3), birthWeightGrams: 400)
        context.insert(puppy)
        let weighIn = WeighIn(date: day(-2), grams: 460)
        weighIn.puppy = puppy
        context.insert(weighIn)

        XCTAssertEqual(puppy.weightSamples.count, 2)
        XCTAssertTrue(puppy.weightSamples.first?.isBirthWeight == true)
        XCTAssertEqual(puppy.latestWeightGrams, 460)
        XCTAssertEqual(puppy.changeSinceLastWeighIn, 60)
    }

    func testAPuppyWithNoBirthWeightDoesNotGetAZeroPoint() {
        let puppy = Puppy(birthOrder: 1, birthWeightGrams: 0)
        context.insert(puppy)
        XCTAssertTrue(puppy.weightSamples.isEmpty, "A zero birth weight must not land on the curve")
        XCTAssertNil(puppy.weightConcern)
    }

    func testPercentOfBirthWeightNeedsABirthWeight() {
        // bornAt has to predate the weigh-in, or the birth-weight sample sorts after it and
        // "latest" ends up meaning the birth weight instead of the actual latest weigh-in.
        let puppy = Puppy(birthOrder: 1, bornAt: day(-3), birthWeightGrams: 400)
        context.insert(puppy)
        let weighIn = WeighIn(date: day(-1), grams: 800)
        weighIn.puppy = puppy
        context.insert(weighIn)
        XCTAssertEqual(puppy.percentOfBirthWeight ?? 0, 200, accuracy: 0.01)
        XCTAssertNil(Puppy(birthOrder: 1).percentOfBirthWeight)
    }

    func testTheLitterSurfacesThePuppyThatStopped() {
        let litter = Litter(name: "Test")
        context.insert(litter)
        for (order, weights) in [(1, [500.0, 560.0]), (2, [500.0, 500.0])] {
            let puppy = Puppy(birthOrder: order, bornAt: day(-4), birthWeightGrams: 440)
            puppy.litter = litter
            context.insert(puppy)
            for (index, grams) in weights.enumerated() {
                let weighIn = WeighIn(date: day(-2 + index), grams: grams)
                weighIn.puppy = puppy
                context.insert(weighIn)
            }
        }
        let flagged = litter.puppiesNeedingAttention()
        XCTAssertEqual(flagged.count, 1)
        XCTAssertEqual(flagged.first?.birthOrder, 2)
    }

    // MARK: Ordering

    func testPuppiesSortByBirthOrderNotByInsertion() {
        let litter = Litter()
        context.insert(litter)
        for order in [3, 1, 2] {
            let puppy = Puppy(birthOrder: order)
            puppy.litter = litter
            context.insert(puppy)
        }
        XCTAssertEqual(litter.pups.map(\.birthOrder), [1, 2, 3])
    }

    func testSeasonsSortOldestFirstBecauseTheIntervalMathsNeedsThat() {
        let dam = Dam(name: "Juno")
        context.insert(dam)
        for offset in [-100, -400, -250] {
            let heat = HeatCycle(startDate: day(offset))
            heat.dam = dam
            context.insert(heat)
        }
        XCTAssertEqual(dam.seasons.map(\.startDate), [day(-400), day(-250), day(-100)])
        XCTAssertEqual(dam.seasonIntervals, [150, 150])
        XCTAssertEqual(dam.averageSeasonIntervalDays, 150)
        XCTAssertEqual(dam.projectedNextSeason, day(50))
    }

    func testSeasonLengthIsNilUntilItHasEnded() {
        let heat = HeatCycle(startDate: day(-10))
        XCTAssertNil(heat.lengthInDays)
        heat.endDate = day(-1)
        XCTAssertEqual(heat.lengthInDays, 9)
    }

    // MARK: Health schedule

    func testTheStandardScheduleCountsFromTheWhelpingDate() {
        let tasks = HealthSchedule.tasks(whelpedAt: day(0))
        XCTAssertEqual(tasks.count, HealthSchedule.standard.count)
        XCTAssertEqual(tasks.first?.name, "Worming 1")
        XCTAssertEqual(tasks.first?.dueDate, day(14))
        XCTAssertEqual(tasks.last?.dueDate, day(56))
    }

    func testScheduleSortIndicesAreStable() {
        let tasks = HealthSchedule.tasks(whelpedAt: day(0))
        XCTAssertEqual(tasks.map(\.sortIndex), Array(0..<tasks.count))
    }

    func testTheScheduleNamesNoProductAndNoDose() {
        for template in HealthSchedule.standard {
            let name = template.name.lowercased()
            for forbidden in ["mg", "ml", "per kg", "dose"] {
                XCTAssertFalse(name.contains(forbidden), "\(template.name) looks like a dose")
            }
        }
    }

    func testMarkingATaskDoneIsPerPuppy() {
        let litter = Litter()
        context.insert(litter)
        let task = HealthTask(name: "Worming 1", dueDate: day(14))
        task.litter = litter
        context.insert(task)
        let first = Puppy(birthOrder: 1); first.litter = litter; context.insert(first)
        let second = Puppy(birthOrder: 2); second.litter = litter; context.insert(second)

        let given = HealthGiven(givenOn: day(14))
        given.task = task
        given.puppy = first
        context.insert(given)

        XCTAssertTrue(task.isDone(for: first))
        XCTAssertFalse(task.isDone(for: second))
        XCTAssertEqual(task.doneCount, 1)
    }

    func testAnUntitledTaskStillHasAColumnHeading() {
        XCTAssertEqual(HealthTask().shortName, "Untitled")
    }

    // MARK: Litter facts and ages

    func testFactsMirrorTheStoredDates() {
        let litter = Litter()
        context.insert(litter)
        litter.seasonStart = day(-90)
        litter.firstMating = day(-80)
        litter.whelpedAt = day(-20)
        let puppy = Puppy(birthOrder: 1)
        puppy.placed = true
        puppy.litter = litter
        context.insert(puppy)

        let facts = litter.facts
        XCTAssertEqual(facts.seasonStart, day(-90))
        XCTAssertEqual(facts.firstMating, day(-80))
        XCTAssertEqual(facts.puppyCount, 1)
        XCTAssertEqual(facts.puppiesPlaced, 1)
    }

    func testAgeIsNilBeforeWhelpingAndCountsInDaysAfter() {
        let litter = Litter()
        XCTAssertNil(litter.ageInDays())
        litter.whelpedAt = day(-21)
        XCTAssertEqual(litter.ageInDays(), 21)
    }

    func testSortDateFallsBackThroughTheTimeline() {
        let litter = Litter()
        context.insert(litter)
        litter.seasonStart = day(-90)
        XCTAssertEqual(litter.sortDate, day(-90))
        litter.firstMating = day(-80)
        XCTAssertEqual(litter.sortDate, day(-80))
        litter.whelpedAt = day(-20)
        XCTAssertEqual(litter.sortDate, day(-20))
    }

    // MARK: CloudKit shape (rule 8)

    func testEveryModelCanBeCreatedWithNoArgumentsSoEveryPropertyIsDefaulted() {
        // If any stored property lost its default this would not compile, which is the point.
        context.insert(Dam())
        context.insert(HeatCycle())
        context.insert(Litter())
        context.insert(Puppy())
        context.insert(WeighIn())
        context.insert(HealthTask())
        context.insert(HealthGiven())
        XCTAssertNoThrow(try context.save())
    }

    func testNoModelDeclaresAUniqueAttribute() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let models = root.appendingPathComponent("WhelpBook/Models")
        let files = try FileManager.default.contentsOfDirectory(at: models, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(source.contains(".unique"),
                           "\(file.lastPathComponent) uses @Attribute(.unique), which CloudKit rejects")
        }
    }
}
