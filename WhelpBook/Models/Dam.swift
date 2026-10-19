import Foundation
import SwiftData

/// A breeding female. Everything in Whelp Book hangs off her: her seasons, and the litters
/// those seasons led to.
///
/// CloudKit shape (CLAUDE.md rule 8): every stored property has a default, nothing is unique,
/// and every to-many relationship is optional.
@Model
final class Dam {
    var id: UUID = UUID()
    var name: String = ""
    var breed: String = ""
    var dateOfBirth: Date? = nil
    var registration: String = ""
    var notes: String = ""
    @Attribute(.externalStorage) var photoData: Data? = nil
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \HeatCycle.dam) var heats: [HeatCycle]? = nil
    @Relationship(deleteRule: .cascade, inverse: \Litter.dam) var litters: [Litter]? = nil

    init(name: String = "", breed: String = "", dateOfBirth: Date? = nil,
         registration: String = "", notes: String = "") {
        self.id = UUID()
        self.name = name
        self.breed = breed
        self.dateOfBirth = dateOfBirth
        self.registration = registration
        self.notes = notes
        self.createdAt = .now
    }
}

extension Dam {
    var displayName: String { name.isEmpty ? "Unnamed dam" : name }

    /// Seasons oldest first, which is the order every interval calculation wants.
    var seasons: [HeatCycle] { (heats ?? []).sorted { $0.startDate < $1.startDate } }

    var litterList: [Litter] { (litters ?? []).sorted { $0.sortDate > $1.sortDate } }

    var seasonStarts: [Date] { seasons.map(\.startDate) }

    /// The number of days between this dam's own seasons. Measured, never assumed — six months is
    /// the textbook figure and plenty of dogs have never read the textbook.
    var seasonIntervals: [Int] { HeatHistory.intervals(starts: seasonStarts) }

    var averageSeasonIntervalDays: Int? { HeatHistory.averageIntervalDays(starts: seasonStarts) }

    var projectedNextSeason: Date? { HeatHistory.projectedNextStart(starts: seasonStarts) }
}

/// One season, recorded as it happens. The start date is the number the interval maths runs on,
/// so it is the one field that is always asked for.
@Model
final class HeatCycle {
    var id: UUID = UUID()
    var startDate: Date = Date()
    var endDate: Date? = nil
    var observations: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var dam: Dam? = nil

    init(startDate: Date = .now, endDate: Date? = nil, observations: String = "", notes: String = "") {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = endDate
        self.observations = observations
        self.notes = notes
        self.createdAt = .now
    }
}

extension HeatCycle {
    var lengthInDays: Int? {
        guard let endDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate),
                                               to: Calendar.current.startOfDay(for: endDate)).day
    }
}
