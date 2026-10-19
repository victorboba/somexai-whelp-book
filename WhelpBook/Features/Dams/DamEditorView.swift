import SwiftUI
import SwiftData

struct DamEditorView: View {
    @Bindable var dam: Dam
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var hasDateOfBirth = false
    @State private var dateOfBirth = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section("Her details") {
                    TextField("Name", text: $dam.name)
                    TextField("Breed", text: $dam.breed)
                    TextField("Registration or kennel name", text: $dam.registration)
                    Toggle("Date of birth known", isOn: $hasDateOfBirth)
                    if hasDateOfBirth {
                        DatePicker("Date of birth", selection: $dateOfBirth, displayedComponents: .date)
                    }
                }
                Section("Photo") {
                    PhotoField(data: $dam.photoData, label: "Photo of the dam", maxSide: 900)
                }
                Section("Notes") {
                    TextEditor(text: $dam.notes).frame(minHeight: 90)
                }
            }
            .navigationTitle(dam.name.isEmpty ? "New dam" : dam.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }.bold()
                }
            }
            .onAppear {
                if let existing = dam.dateOfBirth {
                    hasDateOfBirth = true
                    dateOfBirth = existing
                }
            }
        }
    }

    private func save() {
        dam.dateOfBirth = hasDateOfBirth ? dateOfBirth : nil
        try? context.save()
        dismiss()
    }
}
