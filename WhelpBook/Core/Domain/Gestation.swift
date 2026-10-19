import Foundation

/// A due window, never a due date.
///
/// Gestation in the dog is about 63 days from ovulation and that figure is reliable. Counted from
/// the mating it is not, because sperm survive for days and the tie may have happened well before
/// or after she ovulated; from the matings alone the honest range is roughly 58 to 68 days. Showing
/// one confident date from a tie date would be a false precision the breeder then plans a week
/// around, so Whelp Book shows the window and says what it counted from.
struct DueWindow: Equatable {
    var earliest: Date
    var likely: Date
    var latest: Date
    /// The words that go under the dates: "ovulation" or "the matings".
    var countedFrom: String

    var spanInDays: Int {
        Calendar.current.dateComponents([.day], from: earliest, to: latest).day ?? 0
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        return day >= calendar.startOfDay(for: earliest) && day <= calendar.startOfDay(for: latest)
    }
}

/// A dated checkpoint between the mating and the whelping box. These are calendar entries a
/// breeder acts on, not medical advice: Whelp Book puts a date on the diary and says nothing about
/// what should be done to the dog.
struct WhelpMilestone: Equatable, Identifiable {
    var id: Int { day }
    var day: Int
    var title: String
    var detail: String
    var date: Date

    func isPast(_ now: Date = .now, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: date) < calendar.startOfDay(for: now)
    }
}

enum Gestation {
    /// Days from ovulation to whelping. The one number in canine gestation that is actually tight.
    static let daysFromOvulation = 63
    static let ovulationTolerance = 1

    /// Earliest and latest counted from the matings, when ovulation was never measured.
    static let earliestFromFirstMating = 58
    static let latestFromLastMating = 68

    /// The due window, narrow when ovulation was measured and wide when it was not.
    /// Returns `nil` when there is nothing to count from at all.
    static func window(ovulation: Date?, firstMating: Date?, lastMating: Date?,
                       calendar: Calendar = .current) -> DueWindow? {
        if let ovulation {
            let day = calendar.startOfDay(for: ovulation)
            guard let likely = calendar.date(byAdding: .day, value: daysFromOvulation, to: day),
                  let earliest = calendar.date(byAdding: .day, value: daysFromOvulation - ovulationTolerance, to: day),
                  let latest = calendar.date(byAdding: .day, value: daysFromOvulation + ovulationTolerance, to: day)
            else { return nil }
            return DueWindow(earliest: earliest, likely: likely, latest: latest, countedFrom: "ovulation")
        }

        // Either mating date on its own is enough; a single recorded tie stands in for both.
        let first = firstMating ?? lastMating
        let last = lastMating ?? firstMating
        guard let first, let last else { return nil }
        let firstDay = calendar.startOfDay(for: min(first, last))
        let lastDay = calendar.startOfDay(for: max(first, last))
        guard let earliest = calendar.date(byAdding: .day, value: earliestFromFirstMating, to: firstDay),
              let latest = calendar.date(byAdding: .day, value: latestFromLastMating, to: lastDay),
              let likely = calendar.date(byAdding: .day, value: daysFromOvulation, to: lastDay)
        else { return nil }
        // The likely day always sits inside its own window, whatever the mating dates were.
        let clamped = min(max(likely, earliest), latest)
        return DueWindow(earliest: earliest, likely: clamped, latest: latest, countedFrom: "the matings")
    }

    /// The anchor every milestone counts from: ovulation when it was measured, otherwise the first
    /// mating, which is the earliest day conception could have happened.
    static func anchor(ovulation: Date?, firstMating: Date?) -> Date? { ovulation ?? firstMating }

    private static let schedule: [(day: Int, title: String, detail: String)] = [
        (28, "Pregnancy check possible",
         "From about day 28 a vet can usually tell by ultrasound. Book it if you want to know early."),
        (45, "Whelping box in place",
         "Put the box where she will use it, in the quiet corner you have chosen, so she has weeks to settle into it."),
        (55, "Puppy count possible",
         "Skeletons show on an x-ray from about here. Knowing the count before the night means you know when she has finished."),
        (58, "Start twice-daily temperature",
         "Take her temperature morning and night and write the readings in the litter notes. You are watching for a change from her own normal."),
        (58, "Whelping kit ready",
         "Towels, a scale that reads in grams, clean scissors, your vet's out-of-hours number written down and not just in your phone."),
    ]

    /// Dated checkpoints between the mating and the box. Empty when nothing can be counted from.
    static func milestones(ovulation: Date?, firstMating: Date?, calendar: Calendar = .current) -> [WhelpMilestone] {
        guard let anchor = anchor(ovulation: ovulation, firstMating: firstMating) else { return [] }
        let start = calendar.startOfDay(for: anchor)
        return schedule.compactMap { item in
            guard let date = calendar.date(byAdding: .day, value: item.day, to: start) else { return nil }
            return WhelpMilestone(day: item.day, title: item.title, detail: item.detail, date: date)
        }
    }

    /// The next checkpoint that has not passed yet.
    static func nextMilestone(ovulation: Date?, firstMating: Date?, now: Date = .now,
                              calendar: Calendar = .current) -> WhelpMilestone? {
        milestones(ovulation: ovulation, firstMating: firstMating, calendar: calendar)
            .first { !$0.isPast(now, calendar: calendar) }
    }

    /// How far into gestation she is, counted from the same anchor the milestones use.
    static func dayOfGestation(ovulation: Date?, firstMating: Date?, now: Date = .now,
                               calendar: Calendar = .current) -> Int? {
        guard let anchor = anchor(ovulation: ovulation, firstMating: firstMating) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: anchor),
                                       to: calendar.startOfDay(for: now)).day
    }
}
