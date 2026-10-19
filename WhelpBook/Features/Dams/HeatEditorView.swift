import SwiftUI
import SwiftData

/// One season. The start date is the whole point; everything else is optional colour.
struct HeatEditorView: View {
    @Bindable var heat: HeatCycle
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var hasEnded = false
    @State private var endDate = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("First day of the season", selection: $heat.startDate, displayedComponents: .date)
                    Toggle("She has finished", isOn: $hasEnded)
                    if hasEnded {
                        DatePicker("Last day", selection: $endDate, displayedComponents: .date)
                    }
                }
                Section("What you saw") {
                    TextField("Observations", text: $heat.observations, axis: .vertical)
                        .lineLimit(2...6)
                    Text("Colour, swelling, how she is behaving, progesterone readings if you had them taken. Your words, not a form.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Section("Notes") {
                    TextEditor(text: $heat.notes).frame(minHeight: 80)
                }
                Section {
                    Button("Delete this season", role: .destructive) {
                        context.delete(heat)
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Season")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }.bold()
                }
            }
            .onAppear {
                if let existing = heat.endDate { hasEnded = true; endDate = existing }
            }
        }
    }

    private func save() {
        heat.endDate = hasEnded ? endDate : nil
        try? context.save()
        ReviewPrompter.recordSuccess(request: requestReview)
        dismiss()
    }
}
