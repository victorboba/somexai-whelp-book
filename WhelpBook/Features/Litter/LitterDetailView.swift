import SwiftUI
import SwiftData

/// The dates behind the timeline, and the pre-whelping checkpoints counted from them.
struct LitterDetailView: View {
    @Bindable var litter: Litter
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var editing = false
    @State private var confirmingClose = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                datesCard
                if let window = litter.dueWindow, litter.whelpedAt == nil {
                    dueCard(window)
                }
                if !litter.milestones.isEmpty && litter.whelpedAt == nil {
                    milestonesCard
                }
                if litter.whelpedAt != nil {
                    outcomeCard
                }
                if !litter.notes.isEmpty {
                    WhelpCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes").font(.headline)
                            Text(litter.notes).font(.subheadline).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                DisclaimerNote()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .whelpBackground()
        .navigationTitle(litter.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { editing = true } label: { Label("Edit dates and stud", systemImage: "pencil") }
                    Button { exportLitter() } label: { Label("Litter report as PDF", systemImage: "doc.richtext") }
                    if litter.closedAt == nil {
                        Button { confirmingClose = true } label: { Label("Close this litter", systemImage: "checkmark.seal") }
                    } else {
                        Button { litter.closedAt = nil; try? context.save() } label: {
                            Label("Reopen this litter", systemImage: "arrow.uturn.backward")
                        }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $editing) { LitterEditorView(litter: litter, dams: []) }
        .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
        .confirmationDialog("Close this litter?", isPresented: $confirmingClose, titleVisibility: .visible) {
            Button("Close litter") { litter.closedAt = .now; try? context.save() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The record stays and can still be exported. Reopen it any time.")
        }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK") { exportError = nil }
        } message: { Text(exportError ?? "") }
    }

    private var datesCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("The record").font(.headline)
                row("Dam", litter.dam?.displayName ?? "Not set")
                row("Stud", litter.sireName.isEmpty ? "Not set" : litter.sireName)
                if !litter.sireOwner.isEmpty { row("Stud owner", litter.sireOwner) }
                if !litter.sireRegistration.isEmpty { row("Stud registration", litter.sireRegistration) }
                Divider()
                row("Season started", dateText(litter.seasonStart))
                row("First mating", dateText(litter.firstMating))
                row("Last mating", dateText(litter.lastMating))
                row("Ovulation", dateText(litter.ovulationDate))
                row("Whelped", dateText(litter.whelpedAt))
                row("Go-home date", dateText(litter.goHomeDate))
                Button { editing = true } label: {
                    Label("Edit dates and stud", systemImage: "pencil").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .padding(.top, 4)
            }
        }
    }

    private func dueCard(_ window: DueWindow) -> some View {
        WhelpCard(tint: Theme.accent.opacity(0.12), stroke: Theme.accent.opacity(0.3)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Due window").font(.headline)
                Text(window.likely.formatted(date: .complete, time: .omitted))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.deep)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Any time between \(window.earliest.formatted(date: .abbreviated, time: .omitted)) and \(window.latest.formatted(date: .abbreviated, time: .omitted)), counted from \(window.countedFrom).")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let day = Gestation.dayOfGestation(ovulation: litter.ovulationDate, firstMating: litter.firstMating) {
                    StagePill(text: "Day \(day)", color: Theme.deep)
                }
                if litter.ovulationDate == nil {
                    Text("Add an ovulation date and this window narrows from eleven days to three.")
                        .font(.caption).foregroundStyle(Theme.attention)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var milestonesCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Before the box").font(.headline)
                ForEach(litter.milestones) { milestone in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: milestone.isPast() ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(milestone.isPast() ? Theme.accent : Color.secondary)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(milestone.title)
                                    .font(.subheadline.weight(.medium))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                Text("Day \(milestone.day)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text(milestone.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundStyle(Theme.deep)
                            Text(milestone.detail)
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if milestone.id != litter.milestones.last?.id { Divider() }
                }
                Text("Dates, not advice. What is done on any of them is between you and your vet.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var outcomeCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Outcome").font(.headline)
                let pups = litter.pups
                let males = pups.filter { $0.sex == .male }.count
                let females = pups.filter { $0.sex == .female }.count
                row("Puppies", pups.isEmpty ? "None recorded" : "\(pups.count)")
                row("Males", "\(males)")
                row("Females", "\(females)")
                if let age = litter.ageInDays() {
                    row("Age", LitterTimeline.weeksLabel(age))
                }
                row("Placed", "\(pups.filter(\.placed).count)")
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            Text(value).font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func dateText(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .omitted) ?? "Not set"
    }

    private func exportLitter() {
        do { exportFile = ExportFile(url: try PDFExporter.exportLitter(litter)) }
        catch { exportError = error.localizedDescription }
    }
}
