import Foundation

/// The stages one litter passes through, in order. This is the spine of the app: the home screen
/// is this list, drawn as a rail with the current stage opened up.
enum LitterStage: String, CaseIterable, Identifiable, Codable {
    case season
    case bred
    case expecting
    case whelping
    case raising
    case goingHome
    case closed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .season: return "In season"
        case .bred: return "Bred"
        case .expecting: return "Expecting"
        case .whelping: return "Whelping"
        case .raising: return "Raising puppies"
        case .goingHome: return "Going home"
        case .closed: return "Complete"
        }
    }

    var symbol: String {
        switch self {
        case .season: return "calendar"
        case .bred: return "heart.circle"
        case .expecting: return "clock.badge"
        case .whelping: return "moon.stars"
        case .raising: return "chart.line.uptrend.xyaxis"
        case .goingHome: return "house"
        case .closed: return "checkmark.seal"
        }
    }

    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// One line explaining what this stage is for, shown under the node on the rail.
    var caption: String {
        switch self {
        case .season: return "Her season is recorded and dated."
        case .bred: return "Matings and the stud are on the record."
        case .expecting: return "Counting down to the due window."
        case .whelping: return "The night itself, one puppy at a time."
        case .raising: return "Daily weights, worming and vaccinations."
        case .goingHome: return "Deposits, buyers and go-home dates."
        case .closed: return "Every puppy placed and the record closed."
        }
    }
}

/// Everything the stage calculation needs, with no SwiftData in sight so it can be tested on its own.
struct LitterFacts: Equatable {
    var seasonStart: Date? = nil
    var firstMating: Date? = nil
    var lastMating: Date? = nil
    var ovulation: Date? = nil
    var whelpedAt: Date? = nil
    var puppyCount: Int = 0
    var goHomeDate: Date? = nil
    var puppiesPlaced: Int = 0
    var closedAt: Date? = nil
}

/// Where the litter is now, and the one thing that happens next.
struct LitterStatus: Equatable {
    var stage: LitterStage
    /// The big line at the top of the home screen.
    var headline: String
    /// What happens next, and when. The date is nil when the next step is waiting on the breeder
    /// rather than on the calendar.
    var nextTitle: String
    var nextDate: Date?
    var nextDetail: String
    /// Stages already behind this litter, for filling in the rail.
    var completed: Set<LitterStage>
}

enum LitterTimeline {
    /// Puppies usually go home at eight weeks, so the last week of raising is really the handover
    /// week and the app switches the screen over to buyers then.
    static let goHomeWeekStartsAtDays = 49
    static let typicalGoHomeDays = 56
    /// A mating is a mating until a pregnancy could be confirmed; after that she is expecting.
    static let confirmableAfterDays = 28

    static func status(_ facts: LitterFacts, now: Date = .now, calendar: Calendar = .current) -> LitterStatus {
        var completed: Set<LitterStage> = []
        if facts.seasonStart != nil { completed.insert(.season) }
        if facts.firstMating != nil || facts.lastMating != nil || facts.ovulation != nil {
            completed.insert(.season); completed.insert(.bred)
        }
        if facts.whelpedAt != nil {
            completed.insert(.bred); completed.insert(.expecting); completed.insert(.whelping)
        }

        // Closed, explicitly or because every puppy has gone.
        if facts.closedAt != nil || (facts.puppyCount > 0 && facts.puppiesPlaced >= facts.puppyCount) {
            completed.formUnion([.season, .bred, .expecting, .whelping, .raising, .goingHome])
            let placed = facts.puppiesPlaced
            return LitterStatus(
                stage: .closed,
                headline: placed > 0 ? "All \(placed) placed" : "Litter closed",
                nextTitle: "Keep the record",
                nextDate: nil,
                nextDetail: "Export each puppy's record so the new owners and your own files both have a copy. Start the next litter from her season.",
                completed: completed)
        }

        if let whelpedAt = facts.whelpedAt {
            return afterWhelping(facts, whelpedAt: whelpedAt, now: now, calendar: calendar, completed: completed)
        }

        if let window = Gestation.window(ovulation: facts.ovulation,
                                         firstMating: facts.firstMating,
                                         lastMating: facts.lastMating,
                                         calendar: calendar) {
            return beforeWhelping(facts, window: window, now: now, calendar: calendar, completed: completed)
        }

        if let seasonStart = facts.seasonStart {
            let day = calendar.dateComponents([.day], from: calendar.startOfDay(for: seasonStart),
                                              to: calendar.startOfDay(for: now)).day ?? 0
            return LitterStatus(
                stage: .season,
                headline: day >= 0 ? "Day \(day) of her season" : "Season starts soon",
                nextTitle: "Record the matings",
                nextDate: nil,
                nextDetail: "Once she has been mated, add the dates and the stud. Whelp Book then counts the due window from them.",
                completed: completed)
        }

        return LitterStatus(
            stage: .season,
            headline: "No dates yet",
            nextTitle: "Record the season start",
            nextDate: nil,
            nextDetail: "Everything else counts from here. Open the litter and set the day her season started.",
            completed: completed)
    }

    private static func beforeWhelping(_ facts: LitterFacts, window: DueWindow, now: Date,
                                       calendar: Calendar, completed: Set<LitterStage>) -> LitterStatus {
        let today = calendar.startOfDay(for: now)
        let day = Gestation.dayOfGestation(ovulation: facts.ovulation, firstMating: facts.firstMating,
                                           now: now, calendar: calendar) ?? 0
        let toEarliest = calendar.dateComponents([.day], from: today,
                                                 to: calendar.startOfDay(for: window.earliest)).day ?? 0

        // Inside the window, or past it: she could whelp at any moment, so the app puts the
        // whelping screen in front of everything else.
        if toEarliest <= 0 {
            var done = completed
            done.formUnion([.season, .bred, .expecting])
            let overdue = calendar.dateComponents([.day], from: calendar.startOfDay(for: window.latest),
                                                  to: today).day ?? 0
            return LitterStatus(
                stage: .whelping,
                headline: overdue > 0 ? "Past the window by \(overdue) \(overdue == 1 ? "day" : "days")" : "Due now — day \(day)",
                nextTitle: "Start the whelping log",
                nextDate: nil,
                nextDetail: "Tap Puppy born as each one arrives. Time, order, sex, colour, weight and the placenta, in that order, in a few seconds each.",
                completed: done)
        }

        let stage: LitterStage = day >= confirmableAfterDays ? .expecting : .bred
        var done = completed
        if stage == .expecting { done.insert(.expecting) }

        let next = Gestation.nextMilestone(ovulation: facts.ovulation, firstMating: facts.firstMating,
                                           now: now, calendar: calendar)
        return LitterStatus(
            stage: stage,
            headline: "Day \(day) · due in \(toEarliest) \(toEarliest == 1 ? "day" : "days")",
            nextTitle: next?.title ?? "Due window opens",
            nextDate: next?.date ?? window.earliest,
            nextDetail: next?.detail ?? "Counted from \(window.countedFrom).",
            completed: done)
    }

    private static func afterWhelping(_ facts: LitterFacts, whelpedAt: Date, now: Date,
                                      calendar: Calendar, completed: Set<LitterStage>) -> LitterStatus {
        let age = calendar.dateComponents([.day], from: calendar.startOfDay(for: whelpedAt),
                                          to: calendar.startOfDay(for: now)).day ?? 0
        let count = facts.puppyCount
        let countText = count == 1 ? "1 puppy" : "\(count) puppies"

        // The first day is still the whelping night: she may not have finished.
        if age <= 0 && count > 0 {
            return LitterStatus(
                stage: .whelping,
                headline: "\(countText) so far",
                nextTitle: "Next puppy, or close the night",
                nextDate: nil,
                nextDetail: "Keep tapping Puppy born. When she has finished, take the birth weights and the whelping log becomes the weight chart tomorrow.",
                completed: completed)
        }

        let handoverStart = facts.goHomeDate.map { calendar.date(byAdding: .day, value: -7, to: $0) ?? $0 }
            ?? calendar.date(byAdding: .day, value: goHomeWeekStartsAtDays, to: calendar.startOfDay(for: whelpedAt))

        var done = completed
        let goingHome = handoverStart.map { calendar.startOfDay(for: now) >= calendar.startOfDay(for: $0) } ?? false
        if goingHome { done.insert(.raising) }

        if goingHome {
            let remaining = count - facts.puppiesPlaced
            return LitterStatus(
                stage: .goingHome,
                headline: "\(remaining) of \(count) still here · \(weeksLabel(age))",
                nextTitle: facts.goHomeDate == nil ? "Set go-home dates" : "Hand over the records",
                nextDate: facts.goHomeDate,
                nextDetail: "Open a puppy and export its record: identification, birth details, every weight and everything the vet gave it. That is the document the new owner keeps.",
                completed: done)
        }

        let defaultGoHome = calendar.date(byAdding: .day, value: typicalGoHomeDays,
                                          to: calendar.startOfDay(for: whelpedAt))
        return LitterStatus(
            stage: .raising,
            headline: "\(weeksLabel(age)) old · \(countText)",
            nextTitle: "Today's weigh-in",
            nextDate: facts.goHomeDate ?? defaultGoHome,
            nextDetail: "Weigh every puppy at the same time each day. Whelp Book marks any puppy whose weight did not go up.",
            completed: done)
    }

    /// "12 days old" early on, "5 weeks 2 days" later, because a breeder switches units at about a
    /// fortnight and reading "38 days" takes a moment's arithmetic they should not have to do.
    static func weeksLabel(_ days: Int) -> String {
        if days < 0 { return "not born yet" }
        if days < 14 { return "\(days) \(days == 1 ? "day" : "days")" }
        let weeks = days / 7
        let remainder = days % 7
        if remainder == 0 { return "\(weeks) weeks" }
        return "\(weeks) weeks \(remainder) \(remainder == 1 ? "day" : "days")"
    }

    /// A countdown phrased the way a person would say it, for the "next up" line.
    static func countdown(to date: Date, from now: Date = .now, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "today"
        case 1: return "tomorrow"
        case -1: return "yesterday"
        case let d where d > 1: return "in \(d) days"
        default: return "\(-days) days ago"
        }
    }
}
