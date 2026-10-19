import Foundation

/// Grams and ounces, and the one observation the daily weigh-in exists for.
///
/// Breeders use both units and argue about it, so every weight is stored in grams and shown in
/// both. A puppy that stops gaining is the thing the whole weight chart is for; Whelp Book flags
/// it as a fact about the numbers the breeder entered and stops there. It does not diagnose it,
/// does not name a cause and does not suggest a treatment.
enum WeightMath {
    static let gramsPerOunce = 28.349523125

    static func ounces(fromGrams grams: Double) -> Double { grams / gramsPerOunce }
    static func grams(fromOunces ounces: Double) -> Double { ounces * gramsPerOunce }

    /// "182 g" — grams to the nearest whole gram, because puppy scales do not do better.
    static func gramsString(_ grams: Double) -> String {
        "\(Int(grams.rounded())) g"
    }

    /// "6.4 oz" — one decimal, which is about the resolution of a kitchen scale in ounces.
    static func ouncesString(_ grams: Double) -> String {
        String(format: "%.1f oz", ounces(fromGrams: grams))
    }

    /// The full both-units label used on the puppy screen and in the record.
    static func bothUnits(_ grams: Double) -> String {
        "\(gramsString(grams)) · \(ouncesString(grams))"
    }

    /// A signed change, in grams, with the sign always shown so a gain and a loss never look alike.
    static func changeString(_ grams: Double) -> String {
        let rounded = Int(grams.rounded())
        if rounded > 0 { return "+\(rounded) g" }
        if rounded < 0 { return "\(rounded) g" }
        return "0 g"
    }

    /// What the last weigh-in did compared with the one before it.
    enum Concern: String, Equatable {
        case lost
        case noGain

        /// Deliberately factual. "Needs your attention" is as far as this app goes.
        var label: String {
            switch self {
            case .lost: return "Weight went down"
            case .noGain: return "No gain since last weigh-in"
            }
        }

        var detail: String {
            switch self {
            case .lost: return "This puppy weighed less than at the previous weigh-in. Whelp Book is reporting the numbers you entered, not a diagnosis."
            case .noGain: return "This puppy weighed the same as at the previous weigh-in. Whelp Book is reporting the numbers you entered, not a diagnosis."
            }
        }
    }

    /// Scales are not perfect and neither is a wriggling puppy, so a change smaller than a gram is
    /// treated as no change rather than as a gain of 0.4 g that quietly clears the flag.
    static let tolerance = 1.0

    static func concern(for samples: [WeightSample]) -> Concern? {
        guard let change = changeSincePrevious(samples) else { return nil }
        if change < -tolerance { return .lost }
        if change < tolerance { return .noGain }
        return nil
    }

    /// Change in grams between the last two samples, oldest-first order not assumed.
    static func changeSincePrevious(_ samples: [WeightSample]) -> Double? {
        let sorted = samples.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return nil }
        return sorted[sorted.count - 1].grams - sorted[sorted.count - 2].grams
    }

    /// Total gain from the first recorded weight to the last.
    static func totalGain(_ samples: [WeightSample]) -> Double? {
        let sorted = samples.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last, sorted.count >= 2 else { return nil }
        return last.grams - first.grams
    }

    /// Average grams gained per day across the whole record. `nil` when the samples all land on
    /// the same day, since dividing by zero days would invent a number.
    static func averageDailyGain(_ samples: [WeightSample], calendar: Calendar = .current) -> Double? {
        let sorted = samples.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last, sorted.count >= 2 else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: first.date),
                                           to: calendar.startOfDay(for: last.date)).day ?? 0
        guard days > 0 else { return nil }
        return (last.grams - first.grams) / Double(days)
    }

    /// Parses what the breeder typed in whichever unit the field is set to. Blank and nonsense both
    /// come back as nil rather than as zero, because a zero weight would land on the curve.
    static func parse(_ text: String, unit: WeightUnit) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value > 0 else { return nil }
        return unit == .grams ? value : grams(fromOunces: value)
    }
}

/// Which unit the weigh-in field is currently accepting. Stored per device, not per puppy: a
/// breeder owns one scale and does not switch units halfway through a litter.
enum WeightUnit: String, CaseIterable, Identifiable {
    case grams, ounces
    var id: String { rawValue }
    var label: String { self == .grams ? "Grams" : "Ounces" }
    var suffix: String { self == .grams ? "g" : "oz" }
}
