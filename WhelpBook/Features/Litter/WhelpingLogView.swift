import SwiftUI
import SwiftData

/// The three in the morning screen.
///
/// Everything about this view is shaped by where it gets used: on the floor, in a dim room, with
/// one hand, with a wet puppy in the other, and with the breeder counting. So there is one button
/// and it is enormous, the time is taken automatically the instant it is pressed, and the details
/// come afterwards on big targets. Nothing here is a form that has to be completed before the
/// record exists — the puppy is saved on the first tap and can be corrected in the morning.
struct WhelpingLogView: View {
    @Bindable var litter: Litter
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var quickPuppy: Puppy?
    @State private var now = Date.now
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var pups: [Puppy] { litter.pups }

    var body: some View {
        VStack(spacing: 0) {
            header
            bornButton
            list
        }
        .whelpBackground()
        .navigationTitle("Whelping")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if litter.whelpedAt != nil {
                        Button { litter.whelpedAt = nil; try? context.save() } label: {
                            Label("Clear the whelping date", systemImage: "arrow.uturn.backward")
                        }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("More")
            }
        }
        .sheet(item: $quickPuppy) { puppy in
            PuppyQuickEntryView(puppy: puppy)
        }
        .onReceive(tick) { now = $0 }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(pups.isEmpty ? "No puppies yet" : (pups.count == 1 ? "1 puppy" : "\(pups.count) puppies"))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.deep)
                .accessibilityIdentifier("whelping.count")
            if let last = pups.map(\.bornAt).max() {
                Text("Last one \(sinceLast(last))")
                    .font(.headline)
                    .foregroundStyle(Theme.attention)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Tap the button the moment one arrives. The time is taken for you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.horizontal, 20)
    }

    private var bornButton: some View {
        Button(action: recordBirth) {
            VStack(spacing: 6) {
                Image(systemName: "plus.circle.fill").font(.system(size: 48, weight: .semibold))
                Text("Puppy born").font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Number \(pups.count + 1)").font(.headline).opacity(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 190)
            .background(
                LinearGradient(colors: [Theme.accent, Theme.deep], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .accessibilityIdentifier("whelping.bornButton")
    }

    private var list: some View {
        List {
            if pups.isEmpty {
                Text("Every puppy you record appears here in birth order, newest at the top.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(pups.reversed()) { puppy in
                    Button { quickPuppy = puppy } label: { WhelpRow(puppy: puppy) }
                        .buttonStyle(.plain)
                }
                .onDelete(perform: delete)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func sinceLast(_ date: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        let rest = minutes % 60
        if rest == 0 { return "\(hours) hr ago" }
        return "\(hours) hr \(rest) min ago"
    }

    /// One tap makes the record. Order and time are decided here so the breeder never has to.
    private func recordBirth() {
        let puppy = Puppy(birthOrder: pups.count + 1, bornAt: .now)
        puppy.litter = litter
        context.insert(puppy)
        if litter.whelpedAt == nil { litter.whelpedAt = .now }
        try? context.save()
        ReviewPrompter.recordSuccess(request: requestReview)
        quickPuppy = puppy
    }

    private func delete(_ offsets: IndexSet) {
        let reversed = pups.reversed().map { $0 }
        for index in offsets { context.delete(reversed[index]) }
        try? context.save()
    }
}

private struct WhelpRow: View {
    let puppy: Puppy

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.16)).frame(width: 44, height: 44)
                Text("\(puppy.birthOrder)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.deep)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(puppy.displayName)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detailLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(puppy.bornAt.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                Image(systemName: puppy.placentaPassed ? "checkmark.seal.fill" : "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(puppy.placentaPassed ? Theme.accent : Color.secondary)
                    .accessibilityLabel(puppy.placentaPassed ? "Placenta passed" : "Placenta not recorded")
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var detailLine: String {
        var parts: [String] = [puppy.sex.label]
        if puppy.birthWeightGrams > 0 { parts.append(WeightMath.bothUnits(puppy.birthWeightGrams)) }
        if !puppy.markings.isEmpty { parts.append(puppy.markings) }
        return parts.joined(separator: " · ")
    }
}
