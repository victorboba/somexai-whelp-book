import XCTest
import PDFKit
import SwiftData
@testable import WhelpBook

/// The two documents the app is bought for, plus the CSV that replaces the breeder's spreadsheet.
///
/// `PDFDocument` collapses and rewraps text, and hands padded columns back out of order, so every
/// assertion here normalises whitespace first and checks pieces separately rather than their
/// adjacency (CLAUDE.md rule 7).
@MainActor
final class ExportTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Dam.self, HeatCycle.self, Litter.self, Puppy.self,
                             WeighIn.self, HealthTask.self, HealthGiven.self])
        container = try ModelContainer(for: schema,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: .now))!
    }

    /// A small but complete litter: two puppies, one gaining, one that stalled.
    private func makeLitter() -> Litter {
        let dam = Dam(name: "Juno", breed: "Labrador Retriever", registration: "KC AX01234567")
        context.insert(dam)
        let litter = Litter(name: "Juno x Ridge", sireName: "Ridge", seasonStart: day(-90))
        litter.dam = dam
        litter.sireOwner = "M. Ellery"
        litter.sireRegistration = "KC BZ07761122"
        litter.firstMating = day(-80)
        litter.lastMating = day(-78)
        litter.ovulationDate = day(-81)
        litter.whelpedAt = day(-18)
        litter.goHomeDate = day(38)
        context.insert(litter)

        let red = Puppy(birthOrder: 1, bornAt: day(-18), sex: .male, collar: "Red", birthWeightGrams: 452)
        red.markings = "Black with a white chest flash"
        red.microchip = "981020012345678"
        red.placentaPassed = true
        red.name = "Scout"
        red.buyerName = "The Ashworths"
        red.buyerContact = "07700 900412"
        red.depositPaid = true
        red.litter = litter
        context.insert(red)

        let purple = Puppy(birthOrder: 2, bornAt: day(-18), sex: .female, collar: "Purple", birthWeightGrams: 366)
        purple.markings = "Yellow, pale"
        purple.litter = litter
        context.insert(purple)

        for (index, grams) in [520.0, 590.0, 664.0].enumerated() {
            let weighIn = WeighIn(date: day(-17 + index), grams: grams, notes: index == 0 ? "Morning round" : "")
            weighIn.puppy = red
            context.insert(weighIn)
        }
        // Purple gains, then stops: the case the flag exists for.
        for (index, grams) in [410.0, 470.0, 470.0].enumerated() {
            let weighIn = WeighIn(date: day(-17 + index), grams: grams)
            weighIn.puppy = purple
            context.insert(weighIn)
        }

        let worming = HealthTask(name: "Worming 1", dueDate: day(-4), product: "Panacur oral suspension", sortIndex: 0)
        worming.litter = litter
        context.insert(worming)
        for puppy in [red, purple] {
            let given = HealthGiven(givenOn: day(-4))
            given.task = worming
            given.puppy = puppy
            context.insert(given)
        }

        let vaccination = HealthTask(name: "First vaccination", dueDate: day(24), sortIndex: 1)
        vaccination.litter = litter
        context.insert(vaccination)

        try? context.save()
        return litter
    }

    private func text(of data: Data) throws -> String {
        let document = try XCTUnwrap(PDFDocument(data: data))
        let raw = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
        return raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    // MARK: CSV

    func testCSVHasAHeaderAndOneRowPerWeight() {
        let litter = makeLitter()
        let lines = CSVExporter.csv(for: litter).split(separator: "\n")
        XCTAssertEqual(String(lines[0]), CSVExporter.header)
        // Two puppies, each with a birth weight plus three weigh-ins.
        XCTAssertEqual(lines.count, 1 + 8)
    }

    func testCSVIncludesTheBirthWeightAsItsOwnRow() {
        let litter = makeLitter()
        let csv = CSVExporter.csv(for: litter)
        let birthRows = csv.split(separator: "\n").filter { $0.contains("\"yes\"") }
        XCTAssertEqual(birthRows.count, 2, "Every puppy's birth weight is the first point on its curve")
        XCTAssertTrue(csv.contains("\"452\""))
    }

    func testCSVCarriesBothUnitsAndTheChange() {
        let litter = makeLitter()
        let csv = CSVExporter.csv(for: litter)
        XCTAssertTrue(csv.contains("\"520\""), "grams column")
        XCTAssertTrue(csv.contains("\"18.34\""), "ounces column for 520 g")
        XCTAssertTrue(csv.contains("\"+68\"") || csv.contains("\"68\""), "change column")
    }

    func testCSVRepeatsTheIdentityOnEveryRowSoItPivots() {
        let litter = makeLitter()
        let rows = CSVExporter.csv(for: litter).split(separator: "\n").dropFirst()
        for row in rows {
            XCTAssertTrue(row.contains("\"Juno x Ridge\""))
            XCTAssertTrue(row.contains("\"Ridge\""))
        }
    }

    func testCSVQuotesAndEscapesFields() {
        XCTAssertEqual(CSVExporter.quote(#"say "hi""#), #""say ""hi""""#)
        XCTAssertEqual(CSVExporter.formatted(3), "3")
        XCTAssertEqual(CSVExporter.formatted(2.5), "2.5")
    }

    func testCSVOfAnEmptyLitterIsJustTheHeader() {
        let litter = Litter(name: "Empty")
        context.insert(litter)
        XCTAssertEqual(CSVExporter.csv(for: litter), CSVExporter.header + "\n")
    }

    func testCSVFileIsWritten() throws {
        let litter = makeLitter()
        let url = try CSVExporter.exportWeighIns(litter)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.pathExtension, "csv")
    }

    // MARK: Puppy record

    func testPuppyRecordCarriesItsIdentification() throws {
        let litter = makeLitter()
        let puppy = try XCTUnwrap(litter.pups.first)
        let content = try text(of: PDFExporter.puppyData(puppy))
        XCTAssertTrue(content.contains("Puppy Record"), content.prefix(200).description)
        XCTAssertTrue(content.contains("Scout"))
        XCTAssertTrue(content.contains("981020012345678"))
        XCTAssertTrue(content.contains("Male"))
        XCTAssertTrue(content.contains("Red"))
    }

    func testPuppyRecordNamesBothParents() throws {
        let litter = makeLitter()
        let puppy = try XCTUnwrap(litter.pups.first)
        let content = try text(of: PDFExporter.puppyData(puppy))
        XCTAssertTrue(content.contains("Juno"))
        XCTAssertTrue(content.contains("Ridge"))
        XCTAssertTrue(content.contains("KC AX01234567"))
        XCTAssertTrue(content.contains("KC BZ07761122"))
    }

    func testPuppyRecordListsEveryWeightInBothUnits() throws {
        let litter = makeLitter()
        let puppy = try XCTUnwrap(litter.pups.first)
        let content = try text(of: PDFExporter.puppyData(puppy))
        for grams in ["452 g", "520 g", "590 g", "664 g"] {
            XCTAssertTrue(content.contains(grams), "missing \(grams)")
        }
        XCTAssertTrue(content.contains("oz"), "the ounces column has to be there too")
    }

    func testPuppyRecordSaysWhatTheVetGaveAndWhen() throws {
        let litter = makeLitter()
        let puppy = try XCTUnwrap(litter.pups.first)
        let content = try text(of: PDFExporter.puppyData(puppy))
        XCTAssertTrue(content.contains("Worming 1"))
        XCTAssertTrue(content.contains("Panacur oral suspension"))
        XCTAssertTrue(content.contains("Not given"), "the vaccination nobody has had yet must show as not given")
    }

    func testPuppyRecordCarriesTheNewOwner() throws {
        let litter = makeLitter()
        let puppy = try XCTUnwrap(litter.pups.first)
        let content = try text(of: PDFExporter.puppyData(puppy))
        XCTAssertTrue(content.contains("The Ashworths"))
        XCTAssertTrue(content.contains("07700 900412"))
    }

    func testEveryExportCarriesTheDisclaimer() throws {
        let litter = makeLitter()
        let puppy = try XCTUnwrap(litter.pups.first)
        let normalised = AppConfig.disclaimer.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        XCTAssertTrue(try text(of: PDFExporter.puppyData(puppy)).contains(normalised))
        XCTAssertTrue(try text(of: PDFExporter.litterData(litter)).contains(normalised))
    }

    func testAPuppyWithNothingRecordedStillProducesAReadableRecord() throws {
        let bare = Puppy(birthOrder: 1)
        context.insert(bare)
        let content = try text(of: PDFExporter.puppyData(bare))
        XCTAssertTrue(content.contains("Puppy Record"))
        XCTAssertTrue(content.contains("Not recorded"))
        XCTAssertTrue(content.contains("No weights recorded."))
    }

    // MARK: Litter report

    func testLitterReportHasTheWholeTimeline() throws {
        let litter = makeLitter()
        let content = try text(of: PDFExporter.litterData(litter))
        XCTAssertTrue(content.contains("Litter Report"))
        XCTAssertTrue(content.contains("Juno x Ridge"))
        XCTAssertTrue(content.contains("TIMELINE"), "section headers are drawn upper-cased")
        XCTAssertTrue(content.contains("ovulation"), "the report has to say what the window was counted from")
    }

    func testLitterReportHasTheWhelpingLog() throws {
        let litter = makeLitter()
        let content = try text(of: PDFExporter.litterData(litter))
        XCTAssertTrue(content.contains("WHELPING LOG"))
        XCTAssertTrue(content.contains("Scout"))
        XCTAssertTrue(content.contains("Purple"))
        XCTAssertTrue(content.contains("452 g"))
    }

    func testLitterReportFlagsThePuppyThatStopped() throws {
        let litter = makeLitter()
        let content = try text(of: PDFExporter.litterData(litter))
        XCTAssertTrue(content.contains("No gain since last weigh-in"))
        XCTAssertTrue(content.contains("not a diagnosis"))
    }

    func testLitterReportListsBuyers() throws {
        let litter = makeLitter()
        let content = try text(of: PDFExporter.litterData(litter))
        XCTAssertTrue(content.contains("BUYERS"))
        XCTAssertTrue(content.contains("The Ashworths"))
    }

    func testAnEmptyLitterStillExports() throws {
        let litter = Litter(name: "Nothing yet")
        context.insert(litter)
        let content = try text(of: PDFExporter.litterData(litter))
        XCTAssertTrue(content.contains("No puppies recorded."))
    }

    func testALargeLitterPaginates() throws {
        let litter = makeLitter()
        for index in 3...24 {
            let puppy = Puppy(birthOrder: index, bornAt: day(-18), sex: .male,
                              collar: "Collar \(index)", birthWeightGrams: 400)
            puppy.litter = litter
            context.insert(puppy)
        }
        try context.save()
        let document = try XCTUnwrap(PDFDocument(data: PDFExporter.litterData(litter)))
        XCTAssertGreaterThan(document.pageCount, 1, "24 puppies across four tables must run onto a second page")
    }

    func testFilesAreWrittenWithTheRightExtension() throws {
        let litter = makeLitter()
        let litterURL = try PDFExporter.exportLitter(litter)
        XCTAssertEqual(litterURL.pathExtension, "pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: litterURL.path))
        let puppyURL = try PDFExporter.exportPuppy(try XCTUnwrap(litter.pups.first))
        XCTAssertTrue(puppyURL.lastPathComponent.contains("scout"), puppyURL.lastPathComponent)
    }
}
