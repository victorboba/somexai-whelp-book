import SwiftUI
import SwiftData

/// Start a litter, or correct its dates later.
///
/// The dates here decide the whole timeline, so the screen is honest about what each one buys:
/// an ovulation date narrows the due window to three days, the mating dates alone leave it eleven.
struct LitterEditorView: View {
    let litter: Litter?
    let dams: [Dam]
    var preselected: Dam? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var selectedDam: Dam?
    @State private var name = ""
    @State private var sireName = ""
    @State private var sireOwner = ""
    @State private var sireRegistration = ""
    @State private var hasSeason = false
    @State private var seasonStart = Date.now
    @State private var hasMating = false
    @State private var firstMating = Date.now
    @State private var lastMating = Date.now
    @State private var hasOvulation = false
    @State private var ovulation = Date.now
    @State private var notes = ""

    @Query(sort: \Dam.name) private var allDams: [Dam]

    private var damChoices: [Dam] { allDams.isEmpty ? dams : allDams }

    private var previewWindow: DueWindow? {
        Gestation.window(ovulation: hasOvulation ? ovulation : nil,
                         firstMating: hasMating ? firstMating : nil,
                         lastMating: hasMating ? lastMating : nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("The pairing") {
                    Picker("Dam", selection: $selectedDam) {
                        Text("Choose a dam").tag(Dam?.none)
                        ForEach(damChoices) { dam in
                            Text(dam.displayName).tag(Dam?.some(dam))
                        }
                    }
                    TextField("Stud name", text: $sireName)
                    TextField("Stud owner", text: $sireOwner)
                    TextField("Stud registration", text: $sireRegistration)
                    TextField("Litter name (optional)", text: $name)
                }

                Section("Her season") {
                    Toggle("Season start recorded", isOn: $hasSeason)
                    if hasSeason {
                        DatePicker("First day of the season", selection: $seasonStart, displayedComponents: .date)
                    }
                }

                Section {
                    Toggle("She has been mated", isOn: $hasMating)
                    if hasMating {
                        DatePicker("First mating", selection: $firstMating, displayedComponents: .date)
                        DatePicker("Last mating", selection: $lastMating, displayedComponents: .date)
                    }
                    Toggle("Ovulation date known", isOn: $hasOvulation)
                    if hasOvulation {
                        DatePicker("Ovulation", selection: $ovulation, displayedComponents: .date)
                    }
                } header: {
                    Text("Breeding")
                } footer: {
                    Text("Gestation is about 63 days from ovulation, and that figure is reliable. From the matings alone it is not, because sperm survive for days, so Whelp Book shows a window of about eleven days instead of one confident date you would plan a week around.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let window = previewWindow {
                    Section("Due window") {
                        LabeledContent("Earliest", value: window.earliest.formatted(date: .abbreviated, time: .omitted))
                        LabeledContent("Most likely", value: window.likely.formatted(date: .abbreviated, time: .omitted))
                        LabeledContent("Latest", value: window.latest.formatted(date: .abbreviated, time: .omitted))
                        Text("Counted from \(window.countedFrom).")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 80)
                }
            }
            .navigationTitle(litter == nil ? "Start a litter" : "Edit litter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.bold().disabled(selectedDam == nil)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        if let litter {
            selectedDam = litter.dam
            name = litter.name
            sireName = litter.sireName
            sireOwner = litter.sireOwner
            sireRegistration = litter.sireRegistration
            notes = litter.notes
            if let value = litter.seasonStart { hasSeason = true; seasonStart = value }
            if let value = litter.firstMating { hasMating = true; firstMating = value; lastMating = litter.lastMating ?? value }
            if let value = litter.ovulationDate { hasOvulation = true; ovulation = value }
        } else {
            selectedDam = preselected ?? damChoices.first
            // A new litter usually follows the season that is already on file.
            if let latest = (preselected ?? damChoices.first)?.seasons.last {
                hasSeason = true
                seasonStart = latest.startDate
            }
        }
    }

    private func save() {
        let target: Litter
        if let litter {
            target = litter
        } else {
            target = Litter()
            context.insert(target)
        }
        target.dam = selectedDam
        target.name = name
        target.sireName = sireName
        target.sireOwner = sireOwner
        target.sireRegistration = sireRegistration
        target.notes = notes
        target.seasonStart = hasSeason ? seasonStart : nil
        target.firstMating = hasMating ? min(firstMating, lastMating) : nil
        target.lastMating = hasMating ? max(firstMating, lastMating) : nil
        target.ovulationDate = hasOvulation ? ovulation : nil
        try? context.save()
        ReviewPrompter.recordSuccess(request: requestReview)
        dismiss()
    }
}
