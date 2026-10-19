import Foundation

/// How often this particular dam comes into season.
///
/// The textbook number is about six months, and using it would be the easy thing to do. It would
/// also be wrong often enough to matter: a small terrier can run four months and a big guarding
/// breed can run twelve, and the same dog is usually consistent with herself. So Whelp Book
/// measures the interval from her own record and projects from that, and says nothing at all until
/// there are two seasons to measure between.
enum HeatHistory {

    /// Whole days between consecutive season starts, oldest first. Input order does not matter.
    static func intervals(starts: [Date], calendar: Calendar = .current) -> [Int] {
        let sorted = starts.map { calendar.startOfDay(for: $0) }.sorted()
        guard sorted.count >= 2 else { return [] }
        return zip(sorted, sorted.dropFirst()).compactMap { previous, next in
            calendar.dateComponents([.day], from: previous, to: next).day
        }
    }

    /// The dam's own average interval, rounded to the nearest day. `nil` until there are two
    /// seasons, because one season is not an interval and guessing one would be a lie with a
    /// number on it.
    static func averageIntervalDays(starts: [Date], calendar: Calendar = .current) -> Int? {
        let gaps = intervals(starts: starts, calendar: calendar)
        guard !gaps.isEmpty else { return nil }
        return Int((Double(gaps.reduce(0, +)) / Double(gaps.count)).rounded())
    }

    /// Last season start plus the measured average. `nil` when there is nothing to measure.
    static func projectedNextStart(starts: [Date], calendar: Calendar = .current) -> Date? {
        guard let average = averageIntervalDays(starts: starts, calendar: calendar),
              let last = starts.map({ calendar.startOfDay(for: $0) }).max() else { return nil }
        return calendar.date(byAdding: .day, value: average, to: last)
    }

    /// How spread out her seasons are. A breeder who sees 168, 171, 169 can plan a year ahead; one
    /// who sees 140, 210, 165 cannot, and should be told that rather than shown an average that
    /// pretends otherwise.
    static func spreadInDays(starts: [Date], calendar: Calendar = .current) -> Int? {
        let gaps = intervals(starts: starts, calendar: calendar)
        guard let low = gaps.min(), let high = gaps.max(), gaps.count >= 2 else { return nil }
        return high - low
    }

    /// One plain sentence for the dam screen, matched to how much evidence there actually is.
    static func summary(starts: [Date], now: Date = .now, calendar: Calendar = .current) -> String {
        let gaps = intervals(starts: starts, calendar: calendar)
        switch gaps.count {
        case 0:
            return starts.isEmpty
                ? "No seasons recorded yet. Add the first one and Whelp Book starts measuring her interval."
                : "One season recorded. Add the next one and Whelp Book can measure her own interval."
        case 1:
            return "One interval so far: \(gaps[0]) days. A second makes the projection worth trusting."
        default:
            let average = averageIntervalDays(starts: starts, calendar: calendar) ?? 0
            let low = gaps.min() ?? 0
            let high = gaps.max() ?? 0
            if low == high { return "Every interval has been \(low) days across \(gaps.count) gaps." }
            return "Averaging \(average) days across \(gaps.count) intervals, ranging \(low) to \(high)."
        }
    }

    /// Days from `now` until the projected season. Negative once the projection has passed, which
    /// is information too: it means she is overdue against her own pattern.
    static func daysUntilProjected(starts: [Date], now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let projected = projectedNextStart(starts: starts, calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: projected).day
    }
}
