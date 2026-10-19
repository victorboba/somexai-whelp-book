import Foundation
import SwiftData

/// One column of the litter health grid: a worming or a vaccination the whole litter gets on
/// roughly the same day.
///
/// `product` records what the **vet** chose. Whelp Book never suggests a product, a dose or a
/// schedule of treatment (CLAUDE.md rule 5) — the default dates it offers are a calendar, and the
/// app says so where it offers them.
@Model
final class HealthTask {
    var id: UUID = UUID()
    var name: String = ""
    var dueDate: Date = Date()
    var product: String = ""
    var sortIndex: Int = 0
    var notes: String = ""
    var createdAt: Date = Date()
    var litter: Litter? = nil

    @Relationship(deleteRule: .cascade, inverse: \HealthGiven.task) var given: [HealthGiven]? = nil

    init(name: String = "", dueDate: Date = .now, product: String = "", sortIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.dueDate = dueDate
        self.product = product
        self.sortIndex = sortIndex
        self.createdAt = .now
    }
}

extension HealthTask {
    var records: [HealthGiven] { given ?? [] }

    func isDone(for puppy: Puppy) -> Bool { records.contains { $0.puppy?.id == puppy.id } }

    var doneCount: Int { records.count }

    /// The short label for the grid column header. Two lines, never abbreviated (rule 18).
    var shortName: String { name.isEmpty ? "Untitled" : name }
}

/// The tick in one cell of the grid: this puppy got this task, on this day.
@Model
final class HealthGiven {
    var id: UUID = UUID()
    var givenOn: Date = Date()
    var notes: String = ""
    var task: HealthTask? = nil
    var puppy: Puppy? = nil

    init(givenOn: Date = .now) {
        self.id = UUID()
        self.givenOn = givenOn
    }
}

/// The schedule most small breeders' vets end up on. Offered as a starting calendar the breeder
/// edits, never as a recommendation: the app fills in dates, the vet fills in products.
enum HealthSchedule {
    struct Template { let name: String; let weeks: Int }

    static let standard: [Template] = [
        Template(name: "Worming 1", weeks: 2),
        Template(name: "Worming 2", weeks: 4),
        Template(name: "Worming 3", weeks: 6),
        Template(name: "First vaccination", weeks: 6),
        Template(name: "Worming 4", weeks: 8),
        Template(name: "Second vaccination", weeks: 8),
        Template(name: "Microchip", weeks: 8),
    ]

    /// Dates only, counted from the whelping date. Nothing here is a dose or a product.
    static func tasks(whelpedAt: Date, calendar: Calendar = .current) -> [(name: String, dueDate: Date, sortIndex: Int)] {
        standard.enumerated().compactMap { index, template in
            guard let date = calendar.date(byAdding: .day, value: template.weeks * 7,
                                           to: calendar.startOfDay(for: whelpedAt)) else { return nil }
            return (template.name, date, index)
        }
    }
}
