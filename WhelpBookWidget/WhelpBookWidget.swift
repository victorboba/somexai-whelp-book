import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load())
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct WhelpBookWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if snapshot.hasLitter {
                Text(snapshot.litterName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(snapshot.stageTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(snapshot.headline)
                    .font(.system(.headline, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.8)
                if snapshot.needsAttention > 0 {
                    Label("\(snapshot.needsAttention) needs attention", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if family != .systemSmall {
                    Divider()
                    Text("Next: \(snapshot.nextTitle)")
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                    if let date = snapshot.nextDate {
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(AppConfig.appName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("No litter yet")
                    .font(.system(.headline, design: .rounded))
                Text("Add the dam and start her litter.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct WhelpBookWidget: Widget {
    let kind = "WhelpBookWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            WhelpBookWidgetView(entry: entry)
        }
        .configurationDisplayName(AppConfig.appName)
        .description("Where the active litter is on its timeline, and what happens next.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct WhelpBookWidgetBundle: WidgetBundle {
    var body: some Widget {
        WhelpBookWidget()
    }
}
