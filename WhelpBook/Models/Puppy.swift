import Foundation
import SwiftData

enum PuppySex: String, CaseIterable, Identifiable, Codable {
    case male, female, unrecorded
    var id: String { rawValue }
    var label: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .unrecorded: return "Not recorded"
        }
    }
    /// One letter for the whelping list, where space is tight and the full word is one tap away.
    var shortLabel: String {
        switch self {
        case .male: return "M"
        case .female: return "F"
        case .unrecorded: return "?"
        }
    }
}

/// One puppy. Born on the whelping screen in about four taps, then weighed every morning,
/// ticked off on the health grid, and finally handed over with a record.
@Model
final class Puppy {
    var id: UUID = UUID()
    var name: String = ""
    /// Collar or ribbon colour. Before a puppy is named this is how the breeder tells them apart.
    var collar: String = ""
    var birthOrder: Int = 0
    var sexRaw: String = PuppySex.unrecorded.rawValue
    var markings: String = ""
    var bornAt: Date = Date()
    var birthWeightGrams: Double = 0
    var placentaPassed: Bool = false
    var microchip: String = ""
    var notes: String = ""
    @Attribute(.externalStorage) var photoData: Data? = nil

    // The buyer side of the record.
    var buyerName: String = ""
    var buyerContact: String = ""
    var depositPaid: Bool = false
    var depositAmount: Double = 0
    var goHomeDate: Date? = nil
    var placed: Bool = false
    var buyerNotes: String = ""

    var createdAt: Date = Date()
    var litter: Litter? = nil

    @Relationship(deleteRule: .cascade, inverse: \WeighIn.puppy) var weighIns: [WeighIn]? = nil
    @Relationship(deleteRule: .cascade, inverse: \HealthGiven.puppy) var given: [HealthGiven]? = nil

    init(birthOrder: Int = 0, bornAt: Date = .now, sex: PuppySex = .unrecorded,
         collar: String = "", birthWeightGrams: Double = 0) {
        self.id = UUID()
        self.birthOrder = birthOrder
        self.bornAt = bornAt
        self.sexRaw = sex.rawValue
        self.collar = collar
        self.birthWeightGrams = birthWeightGrams
        self.createdAt = .now
    }
}

extension Puppy {
    var sex: PuppySex {
        get { PuppySex(rawValue: sexRaw) ?? .unrecorded }
        set { sexRaw = newValue.rawValue }
    }

    /// What to call this puppy on screen: the name if it has one, otherwise the collar colour,
    /// otherwise its place in the birth order. Never blank, never truncated.
    var displayName: String {
        if !name.isEmpty { return name }
        if !collar.isEmpty { return "\(collar) collar" }
        return "Puppy \(birthOrder)"
    }

    var weights: [WeighIn] { (weighIns ?? []).sorted { $0.date < $1.date } }

    /// Every weight the app knows about, birth weight included, oldest first. The birth weight is
    /// a real data point on the growth curve and leaving it off loses the first day.
    var weightSamples: [WeightSample] {
        var samples: [WeightSample] = []
        if birthWeightGrams > 0 {
            samples.append(WeightSample(date: bornAt, grams: birthWeightGrams, isBirthWeight: true))
        }
        samples.append(contentsOf: weights.map { WeightSample(date: $0.date, grams: $0.grams) })
        return samples.sorted { $0.date < $1.date }
    }

    var latestWeightGrams: Double? { weightSamples.last?.grams }

    /// Set when the last weigh-in did not go up. Whelp Book states what the numbers did; what it
    /// means is for the breeder and their vet.
    var weightConcern: WeightMath.Concern? { WeightMath.concern(for: weightSamples) }

    var changeSinceLastWeighIn: Double? { WeightMath.changeSincePrevious(weightSamples) }

    var percentOfBirthWeight: Double? {
        guard birthWeightGrams > 0, let latest = latestWeightGrams else { return nil }
        return latest / birthWeightGrams * 100
    }

    func ageInDays(now: Date = .now) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: bornAt),
                                       to: calendar.startOfDay(for: now)).day ?? 0
    }

    func wasGiven(_ task: HealthTask) -> HealthGiven? {
        (given ?? []).first { $0.task?.id == task.id }
    }
}

/// One weigh-in. Stored in grams whatever the breeder typed, because a single storage unit is the
/// only way a growth curve stays honest; the display converts.
@Model
final class WeighIn {
    var id: UUID = UUID()
    var date: Date = Date()
    var grams: Double = 0
    var notes: String = ""
    var puppy: Puppy? = nil

    init(date: Date = .now, grams: Double = 0, notes: String = "") {
        self.id = UUID()
        self.date = date
        self.grams = grams
        self.notes = notes
    }
}

/// A point on the growth curve, free of SwiftData so the maths can be unit tested on its own.
struct WeightSample: Equatable, Identifiable {
    var id: Date { date }
    var date: Date
    var grams: Double
    var isBirthWeight: Bool = false
}
