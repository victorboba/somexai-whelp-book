import Foundation

/// A tiny summary the app writes to the shared App Group so the widget can render without touching
/// SwiftData. It carries the same two things the home screen leads with: where the active litter is
/// on its timeline, and what happens next.
struct WidgetSnapshot: Codable {
    var litterName: String = ""
    var stageTitle: String = ""
    var headline: String = ""
    var nextTitle: String = ""
    var nextDate: Date? = nil
    var puppyCount: Int = 0
    var needsAttention: Int = 0
    var updatedAt: Date = .now

    static let storageKey = "widget.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults.set(data, forKey: Self.storageKey)
    }

    var hasLitter: Bool { !litterName.isEmpty }

    static let placeholder = WidgetSnapshot(
        litterName: "Juno x Ridge",
        stageTitle: "Raising puppies",
        headline: "3 weeks old · 7 puppies",
        nextTitle: "Today's weigh-in",
        nextDate: .now,
        puppyCount: 7,
        needsAttention: 1)
}
