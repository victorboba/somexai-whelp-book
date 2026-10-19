import SwiftUI
import SwiftData

/// Where a litter is on a route it is definitely going to take.
enum WhelpDestination: Hashable {
    case dams
    case dam(Dam)
    case litterDetail(Litter)
    case whelping(Litter)
    case weights(Litter)
    case health(Litter)
    case buyers(Litter)
    case puppy(Puppy)
    case howTo
}

/// The home screen is the litter's timeline, not a list of records.
///
/// A heat calendar, a whelping log and a weight spreadsheet are three apps because nobody joined
/// them up. Joined up, they are one thing: a rail with seven stages on it, the current one opened,
/// and exactly one action under it. Everything else in the app is reachable from a stage on that
/// rail, which is why the rail is the screen rather than a tab bar or a list of entries.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Litter.createdAt, order: .reverse) private var litters: [Litter]
    @Query(sort: \Dam.name) private var dams: [Dam]

    @AppStorage("home.activeLitter") private var activeLitterID = ""
    @State private var path: [WhelpDestination] = []
    @State private var showingSettings = false
    @State private var showingNewLitter = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?
    @State private var now = Date.now

    private var activeLitter: Litter? {
        if let stored = UUID(uuidString: activeLitterID),
           let match = litters.first(where: { $0.id == stored }) {
            return match
        }
        return litters.filter { $0.closedAt == nil }.sorted { $0.sortDate > $1.sortDate }.first ?? litters.first
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 16) {
                    if let litter = activeLitter {
                        litterTimeline(litter)
                    } else {
                        startHere
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .whelpBackground()
            .navigationTitle(AppConfig.appName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .navigationDestination(for: WhelpDestination.self, destination: destination)
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $showingNewLitter) { LitterEditorView(litter: nil, dams: dams) }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .alert("Export failed", isPresented: Binding(get: { exportError != nil },
                                                         set: { if !$0 { exportError = nil } })) {
                Button("OK") { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
        .onChange(of: litters.count, initial: true) { WidgetSync.update(litters: litters, now: now) }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            now = .now
            WidgetSync.update(litters: litters, now: now)
            openWeighInIfRequestedByShortcut()
        }
    }

    // MARK: The timeline

    @ViewBuilder
    private func litterTimeline(_ litter: Litter) -> some View {
        let status = litter.status(now: now)

        LitterHeaderCard(litter: litter, status: status, now: now)

        NextUpCard(status: status, now: now)

        StageRail(litter: litter, status: status, now: now) { destination in
            path.append(destination)
        }

        let flagged = litter.puppiesNeedingAttention(now: now)
        if !flagged.isEmpty {
            AttentionCard(puppies: flagged) { path.append(.weights(litter)) }
        }

        QuickJumpGrid(litter: litter, status: status) { path.append($0) }

        if litters.count > 1 {
            OtherLittersCard(litters: litters.filter { $0.id != litter.id }, now: now) { other in
                activeLitterID = other.id.uuidString
            }
        }

        DisclaimerNote()
    }

    private var startHere: some View {
        VStack(spacing: 16) {
            WhelpCard(tint: Theme.accent.opacity(0.12), stroke: Theme.accent.opacity(0.35)) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "pawprint.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.accent)
                    Text("One record, from her season to the day they leave")
                        .font(.title3.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Add the dam first. Her seasons, the matings, the whelping night and every puppy's weight all hang off her, on one timeline.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        path.append(.dams)
                    } label: {
                        Label("Add a dam", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Theme.accent)
                }
            }

            if !dams.isEmpty {
                WhelpCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("She is on file. Start her litter.")
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("A litter runs from the season that started it through to the last puppy going home.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            showingNewLitter = true
                        } label: {
                            Label("Start a litter", systemImage: "heart.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .tint(Theme.accent)
                    }
                }
            }

            DisclaimerNote()
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                .accessibilityLabel("Settings")
            NavigationLink(value: WhelpDestination.howTo) {
                Image(systemName: "questionmark.circle")
            }
            .accessibilityLabel("How do I use this app?")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Button { showingNewLitter = true } label: { Label("Start a litter", systemImage: "heart.circle") }
                Button { path.append(.dams) } label: { Label("Dams and seasons", systemImage: "pawprint") }
                if let litter = activeLitter {
                    Divider()
                    Button { export(.litterPDF, litter) } label: { Label("Litter report as PDF", systemImage: "doc.richtext") }
                    Button { export(.weighInCSV, litter) } label: { Label("Every weigh-in as CSV", systemImage: "tablecells") }
                }
                if litters.count > 1 {
                    Divider()
                    Picker("Active litter", selection: Binding(get: { activeLitterID },
                                                               set: { activeLitterID = $0 })) {
                        ForEach(litters) { litter in
                            Text(litter.displayName).tag(litter.id.uuidString)
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("More")
        }
    }

    @ViewBuilder
    private func destination(_ destination: WhelpDestination) -> some View {
        switch destination {
        case .dams: DamsView()
        case .dam(let dam): DamDetailView(dam: dam)
        case .litterDetail(let litter): LitterDetailView(litter: litter)
        case .whelping(let litter): WhelpingLogView(litter: litter)
        case .weights(let litter): WeightsView(litter: litter)
        case .health(let litter): HealthGridView(litter: litter)
        case .buyers(let litter): BuyersView(litter: litter)
        case .puppy(let puppy): PuppyDetailView(puppy: puppy)
        case .howTo: HowToView()
        }
    }

    // MARK: Export

    private enum ExportKind { case litterPDF, weighInCSV }

    private func export(_ kind: ExportKind, _ litter: Litter) {
        do {
            let url = kind == .litterPDF
                ? try PDFExporter.exportLitter(litter)
                : try CSVExporter.exportWeighIns(litter)
            exportFile = ExportFile(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    /// The Siri shortcut sets a flag and opens the app; the app decides where that lands.
    private func openWeighInIfRequestedByShortcut() {
        let defaults = WidgetSnapshot.defaults
        guard defaults.bool(forKey: LogWeighInIntent.pendingKey) else { return }
        defaults.removeObject(forKey: LogWeighInIntent.pendingKey)
        guard let litter = activeLitter else { return }
        path = litter.whelpedAt == nil ? [.whelping(litter)] : [.weights(litter)]
    }
}

// MARK: - Header

private struct LitterHeaderCard: View {
    let litter: Litter
    let status: LitterStatus
    let now: Date

    var body: some View {
        WhelpCard(tint: Theme.accent.opacity(0.14), stroke: Theme.accent.opacity(0.30)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(litter.displayName)
                            .font(.title3.bold())
                            .fixedSize(horizontal: false, vertical: true)
                        Text(litter.pairing)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    StagePill(text: status.stage.title, color: Theme.deep, symbol: status.stage.symbol)
                }
                Text(status.headline)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.deep)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("litter.headline")
                if let window = litter.dueWindow, litter.whelpedAt == nil {
                    Text("Due between \(window.earliest.formatted(date: .abbreviated, time: .omitted)) and \(window.latest.formatted(date: .abbreviated, time: .omitted)), counted from \(window.countedFrom).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Next up

private struct NextUpCard: View {
    let status: LitterStatus
    let now: Date

    var body: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right").font(.caption)
                    Text("Next").font(.caption.weight(.semibold)).textCase(.uppercase)
                }
                .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline) {
                    Text(status.nextTitle)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if let date = status.nextDate {
                        Text(LitterTimeline.countdown(to: date, from: now))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.attention)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let date = status.nextDate {
                    Text(date.formatted(date: .complete, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(status.nextDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - The rail

private struct StageRail: View {
    let litter: Litter
    let status: LitterStatus
    let now: Date
    let open: (WhelpDestination) -> Void

    var body: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("This litter")
                    .font(.caption.weight(.semibold)).textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 10)

                ForEach(Array(LitterStage.allCases.enumerated()), id: \.element) { index, stage in
                    StageRow(stage: stage,
                             isLast: index == LitterStage.allCases.count - 1,
                             current: status.stage,
                             completed: status.completed,
                             subtitle: subtitle(for: stage)) {
                        open(destination(for: stage))
                    }
                }
            }
        }
    }

    private func subtitle(for stage: LitterStage) -> String {
        let calendar = Calendar.current
        switch stage {
        case .season:
            guard let date = litter.seasonStart else { return "Not recorded" }
            return "Started \(date.formatted(date: .abbreviated, time: .omitted))"
        case .bred:
            if let first = litter.firstMating, let last = litter.lastMating, !calendar.isDate(first, inSameDayAs: last) {
                return "Mated \(first.formatted(date: .abbreviated, time: .omitted)) to \(last.formatted(date: .abbreviated, time: .omitted))"
            }
            if let only = litter.firstMating ?? litter.lastMating {
                return "Mated \(only.formatted(date: .abbreviated, time: .omitted))"
            }
            return "No mating dates yet"
        case .expecting:
            guard let window = litter.dueWindow else { return "Waiting on mating dates" }
            return "Due around \(window.likely.formatted(date: .abbreviated, time: .omitted))"
        case .whelping:
            guard let whelped = litter.whelpedAt else { return "Not started" }
            let count = litter.pups.count
            return "\(whelped.formatted(date: .abbreviated, time: .omitted)) · \(count == 1 ? "1 puppy" : "\(count) puppies")"
        case .raising:
            guard let age = litter.ageInDays(now: now), age >= 0 else { return "After the whelping" }
            let weighed = litter.pups.filter { !$0.weights.isEmpty }.count
            return "\(LitterTimeline.weeksLabel(age)) old · \(weighed) weighed"
        case .goingHome:
            let placed = litter.pups.filter(\.placed).count
            if let date = litter.goHomeDate {
                return "\(date.formatted(date: .abbreviated, time: .omitted)) · \(placed) placed"
            }
            return placed > 0 ? "\(placed) placed" : "No go-home date set"
        case .closed:
            guard let closed = litter.closedAt else { return "Once every puppy has gone" }
            return "Closed \(closed.formatted(date: .abbreviated, time: .omitted))"
        }
    }

    private func destination(for stage: LitterStage) -> WhelpDestination {
        switch stage {
        case .season, .bred, .expecting, .closed: return .litterDetail(litter)
        case .whelping: return .whelping(litter)
        case .raising: return .weights(litter)
        case .goingHome: return .buyers(litter)
        }
    }
}

private struct StageRow: View {
    let stage: LitterStage
    let isLast: Bool
    let current: LitterStage
    let completed: Set<LitterStage>
    let subtitle: String
    let action: () -> Void

    private var isCurrent: Bool { stage == current }
    private var isDone: Bool { completed.contains(stage) && !isCurrent }
    private var color: Color { Theme.stageColor(stage, current: current, completed: completed) }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(isCurrent ? color : (isDone ? color : Color.clear))
                            .frame(width: isCurrent ? 30 : 22, height: isCurrent ? 30 : 22)
                        Circle()
                            .strokeBorder(color, lineWidth: 2)
                            .frame(width: isCurrent ? 30 : 22, height: isCurrent ? 30 : 22)
                        if isDone {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        } else if isCurrent {
                            Image(systemName: stage.symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        }
                    }
                    if !isLast {
                        Rectangle()
                            .fill(color.opacity(0.45))
                            .frame(width: 3)
                            .frame(minHeight: 26)
                    }
                }
                .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(stage.title)
                        .font(isCurrent ? .headline : .subheadline.weight(.medium))
                        .foregroundStyle(isCurrent ? Theme.deep : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if isCurrent {
                        Text(stage.caption)
                            .font(.caption)
                            .foregroundStyle(Theme.attention)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.bottom, isLast ? 0 : 14)

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("stage.\(stage.rawValue)")
    }
}

// MARK: - Attention

private struct AttentionCard: View {
    let puppies: [Puppy]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            WhelpCard(tint: Theme.attention.opacity(0.12), stroke: Theme.attention.opacity(0.40)) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Needs your attention", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.attention)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(puppies) { puppy in
                        Text("\(puppy.displayName) — \(puppy.weightConcern?.label ?? "")")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("These are the numbers you entered, not a diagnosis. Whelp Book does not give veterinary advice.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("attention.card")
    }
}

// MARK: - Quick jumps

private struct QuickJumpGrid: View {
    let litter: Litter
    let status: LitterStatus
    let open: (WhelpDestination) -> Void

    private var items: [(String, String, WhelpDestination, String)] {
        [
            ("Whelping", "moon.stars", .whelping(litter), litter.pups.isEmpty ? "No puppies yet" : "\(litter.pups.count) recorded"),
            ("Weights", "scalemass", .weights(litter), weightsSubtitle),
            ("Health", "cross.case", .health(litter), healthSubtitle),
            ("Buyers", "house", .buyers(litter), "\(litter.pups.filter(\.placed).count) of \(litter.pups.count) placed"),
        ]
    }

    private var weightsSubtitle: String {
        let total = litter.pups.reduce(0) { $0 + $1.weights.count }
        return total == 0 ? "No weigh-ins yet" : "\(total) weigh-ins"
    }

    private var healthSubtitle: String {
        let tasks = litter.healthTasks
        guard !tasks.isEmpty else { return "No dates set" }
        let cells = tasks.count * max(litter.pups.count, 1)
        let done = tasks.reduce(0) { $0 + $1.doneCount }
        return "\(done) of \(cells) done"
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(items, id: \.0) { title, symbol, destination, subtitle in
                Button { open(destination) } label: {
                    WhelpCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: symbol)
                                .font(.title3)
                                .foregroundStyle(Theme.accent)
                            Text(title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("jump.\(title.lowercased())")
            }
        }
    }
}

// MARK: - Other litters

private struct OtherLittersCard: View {
    let litters: [Litter]
    let now: Date
    let select: (Litter) -> Void

    var body: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Other litters")
                    .font(.caption.weight(.semibold)).textCase(.uppercase)
                    .foregroundStyle(.secondary)
                ForEach(litters) { litter in
                    Button { select(litter) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(litter.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(litter.status(now: now).headline)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            StagePill(text: litter.status(now: now).stage.title, color: Theme.accent)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct DisclaimerNote: View {
    var body: some View {
        Text(AppConfig.disclaimer)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}
