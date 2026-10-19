import Foundation
import WidgetKit

enum WidgetSync {
    /// Recomputes the widget summary from the active litter and reloads timelines.
    /// The active litter is the most recent one that has not been closed, which is what the home
    /// screen shows too.
    static func update(litters: [Litter], now: Date = .now) {
        var snapshot = WidgetSnapshot()
        let open = litters.filter { $0.closedAt == nil }.sorted { $0.sortDate > $1.sortDate }
        if let litter = open.first ?? litters.sorted(by: { $0.sortDate > $1.sortDate }).first {
            let status = litter.status(now: now)
            snapshot.litterName = litter.displayName
            snapshot.stageTitle = status.stage.title
            snapshot.headline = status.headline
            snapshot.nextTitle = status.nextTitle
            snapshot.nextDate = status.nextDate
            snapshot.puppyCount = litter.pups.count
            snapshot.needsAttention = litter.puppiesNeedingAttention(now: now).count
        }
        snapshot.updatedAt = now
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
