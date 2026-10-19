import Foundation
import SwiftData

/// One litter, from the season that started it to the day the last puppy goes home.
///
/// This is the record that makes Whelp Book one app instead of three. A heat calendar, a whelping
/// night log and a weight spreadsheet each hold a third of this and none of them knows about the
/// other two.
@Model
final class Litter {
    var id: UUID = UUID()
    var name: String = ""
    var sireName: String = ""
    var sireOwner: String = ""
    var sireRegistration: String = ""

    /// The season this litter came out of. Copied from the dam's heat record when the litter is
    /// created, and editable, because a breeder sometimes back-fills a litter after the fact.
    var seasonStart: Date? = nil
    var firstMating: Date? = nil
    var lastMating: Date? = nil
    /// Set only when it was actually measured (progesterone or a vet's call). When it is present
    /// the due window narrows, because gestation is counted from ovulation, not from the tie.
    var ovulationDate: Date? = nil

    var whelpedAt: Date? = nil
    var goHomeDate: Date? = nil
    var closedAt: Date? = nil
    var notes: String = ""
    var createdAt: Date = Date()

    var dam: Dam? = nil
    @Relationship(deleteRule: .cascade, inverse: \Puppy.litter) var puppies: [Puppy]? = nil
    @Relationship(deleteRule: .cascade, inverse: \HealthTask.litter) var tasks: [HealthTask]? = nil

    init(name: String = "", sireName: String = "", seasonStart: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.sireName = sireName
        self.seasonStart = seasonStart
        self.createdAt = .now
    }
}

extension Litter {
    var pups: [Puppy] {
        (puppies ?? []).sorted {
            if $0.birthOrder != $1.birthOrder { return $0.birthOrder < $1.birthOrder }
            return $0.bornAt < $1.bornAt
        }
    }

    var healthTasks: [HealthTask] {
        (tasks ?? []).sorted {
            if $0.dueDate != $1.dueDate { return $0.dueDate < $1.dueDate }
            return $0.sortIndex < $1.sortIndex
        }
    }

    /// What the litter is called on screen. Falls back to the pairing, then to the dam alone.
    var displayName: String {
        if !name.isEmpty { return name }
        let damName = dam?.displayName ?? "Litter"
        if !sireName.isEmpty { return "\(damName) x \(sireName)" }
        return damName
    }

    var pairing: String {
        let damName = dam?.displayName ?? "Dam not set"
        return sireName.isEmpty ? damName : "\(damName) x \(sireName)"
    }

    /// The date the litter sorts by: the most definite thing that has happened to it.
    var sortDate: Date { whelpedAt ?? lastMating ?? firstMating ?? seasonStart ?? createdAt }

    var facts: LitterFacts {
        LitterFacts(seasonStart: seasonStart,
                    firstMating: firstMating,
                    lastMating: lastMating,
                    ovulation: ovulationDate,
                    whelpedAt: whelpedAt,
                    puppyCount: pups.count,
                    goHomeDate: goHomeDate,
                    puppiesPlaced: pups.filter(\.placed).count,
                    closedAt: closedAt)
    }

    func status(now: Date = .now) -> LitterStatus { LitterTimeline.status(facts, now: now) }

    var dueWindow: DueWindow? {
        Gestation.window(ovulation: ovulationDate, firstMating: firstMating, lastMating: lastMating)
    }

    var milestones: [WhelpMilestone] {
        Gestation.milestones(ovulation: ovulationDate, firstMating: firstMating)
    }

    /// Age of the litter in days, once there is a whelping date to count from.
    func ageInDays(now: Date = .now) -> Int? {
        guard let whelpedAt else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: whelpedAt),
                                       to: calendar.startOfDay(for: now)).day
    }

    /// Puppies whose last weigh-in did not go up. A factual observation about the numbers the
    /// breeder entered, never a diagnosis.
    func puppiesNeedingAttention(now: Date = .now) -> [Puppy] {
        pups.filter { $0.weightConcern != nil }
    }
}
