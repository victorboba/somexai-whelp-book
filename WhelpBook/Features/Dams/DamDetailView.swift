import SwiftUI
import SwiftData

/// Her seasons, the interval measured from them, and every litter she has had.
///
/// The projection is the point of this screen. Six months is the number everyone quotes; a
/// particular bitch runs her own number and is usually consistent with it, so Whelp Book measures
/// hers and says nothing until it has two seasons to measure between.
struct DamDetailView: View {
    @Bindable var dam: Dam
    @Environment(\.modelContext) private var context

    @State private var editingDam = false
    @State private var editingHeat: HeatCycle?
    @State private var startingLitter = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileCard
                intervalCard
                seasonsCard
                littersCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .whelpBackground()
        .navigationTitle(dam.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { editingDam = true } label: { Label("Edit dam", systemImage: "pencil") }
                    Button { addSeason() } label: { Label("Add a season", systemImage: "calendar.badge.plus") }
                    Button { startingLitter = true } label: { Label("Start a litter", systemImage: "heart.circle") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $editingDam) { DamEditorView(dam: dam) }
        .sheet(item: $editingHeat) { HeatEditorView(heat: $0) }
        .sheet(isPresented: $startingLitter) { LitterEditorView(litter: nil, dams: [dam], preselected: dam) }
    }

    private var profileCard: some View {
        WhelpCard(tint: Theme.accent.opacity(0.12), stroke: Theme.accent.opacity(0.28)) {
            HStack(alignment: .top, spacing: 14) {
                DamAvatar(dam: dam, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(dam.displayName).font(.title3.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    if !dam.breed.isEmpty {
                        Text(dam.breed).font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let dob = dam.dateOfBirth {
                        Text("Born \(dob.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !dam.registration.isEmpty {
                        Text(dam.registration).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var intervalCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("Her own interval", systemImage: "arrow.left.and.right")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(HeatHistory.summary(starts: dam.seasonStarts))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("dam.intervalSummary")
                if let projected = dam.projectedNextSeason {
                    Divider()
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next season expected")
                                .font(.caption.weight(.semibold)).textCase(.uppercase)
                                .foregroundStyle(.secondary)
                            Text(projected.formatted(date: .complete, time: .omitted))
                                .font(.headline)
                                .foregroundStyle(Theme.deep)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Text(LitterTimeline.countdown(to: projected))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.attention)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Projected from her own record, not from a breed average.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var seasonsCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Seasons").font(.headline)
                    Spacer()
                    Button { addSeason() } label: { Label("Add a season", systemImage: "plus") }
                        .font(.subheadline)
                        .tint(Theme.accent)
                }
                if dam.seasons.isEmpty {
                    Text("No seasons recorded. Add the day her season started; everything else counts from there.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    let gaps = dam.seasonIntervals
                    ForEach(Array(dam.seasons.reversed().enumerated()), id: \.element.id) { index, season in
                        Button { editingHeat = season } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(season.startDate.formatted(date: .long, time: .omitted))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if let length = season.lengthInDays {
                                        Text("Ran \(length) days").font(.caption).foregroundStyle(.secondary)
                                    }
                                    if !season.observations.isEmpty {
                                        Text(season.observations).font(.caption).foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Spacer(minLength: 8)
                                if let gap = gapBefore(index: index, gaps: gaps) {
                                    StagePill(text: "\(gap) days on", color: Theme.deep)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if season.id != dam.seasons.first?.id { Divider() }
                    }
                }
            }
        }
    }

    /// The gap shown against a season is the one that led up to it, which for a reversed list is
    /// counted from the end of the intervals array.
    private func gapBefore(index: Int, gaps: [Int]) -> Int? {
        let position = gaps.count - 1 - index
        guard position >= 0, position < gaps.count else { return nil }
        return gaps[position]
    }

    private var littersCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Litters").font(.headline)
                    Spacer()
                    Button { startingLitter = true } label: { Label("Start a litter", systemImage: "plus") }
                        .font(.subheadline)
                        .tint(Theme.accent)
                }
                if dam.litterList.isEmpty {
                    Text("No litters yet.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(dam.litterList) { litter in
                        NavigationLink(value: WhelpDestination.litterDetail(litter)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(litter.displayName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(litter.status().headline)
                                        .font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 8)
                                StagePill(text: litter.status().stage.title, color: Theme.accent)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func addSeason() {
        let heat = HeatCycle()
        heat.dam = dam
        context.insert(heat)
        try? context.save()
        editingHeat = heat
    }
}
