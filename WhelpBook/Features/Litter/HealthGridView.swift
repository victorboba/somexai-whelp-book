import SwiftUI
import SwiftData

/// Worming and vaccination across the whole litter, as a grid: one row per puppy, one column per
/// event, tap a cell to mark it done.
///
/// A list would make the breeder count seven puppies times six events in their head. The grid is
/// the whole point: you can see at a glance that the blue collar boy has not had his second
/// worming. The product column records what the **vet** chose; Whelp Book never suggests one and
/// never computes a dose.
struct HealthGridView: View {
    @Bindable var litter: Litter
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var editingTask: HealthTask?
    @State private var addingTask = false

    private var pups: [Puppy] { litter.pups }
    private var tasks: [HealthTask] { litter.healthTasks }

    private let nameColumnWidth: CGFloat = 132
    private let cellWidth: CGFloat = 92

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if pups.isEmpty {
                    WhelpCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No puppies yet").font(.headline)
                            Text("Record the litter on the whelping screen and the grid builds itself, one row per puppy.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else if tasks.isEmpty {
                    emptyTasksCard
                } else {
                    gridCard
                    productsCard
                }
                DisclaimerNote()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .whelpBackground()
        .navigationTitle("Health")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { addingTask = true } label: { Label("Add an event", systemImage: "plus") }
                    if tasks.isEmpty, litter.whelpedAt != nil {
                        Button { addStandardSchedule() } label: { Label("Add the usual dates", systemImage: "calendar.badge.plus") }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("More")
            }
        }
        .sheet(item: $editingTask) { HealthTaskEditorView(task: $0) }
        .sheet(isPresented: $addingTask) {
            if let task = makeTask() { HealthTaskEditorView(task: task) }
        }
    }

    private var emptyTasksCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("No events yet").font(.headline)
                Text("Whelp Book can lay out the dates most litters run on — wormings at two, four, six and eight weeks, vaccinations and the microchip — counted from the whelping date. They are dates, not advice: your vet decides what is actually given, and you type the product in here afterwards.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if litter.whelpedAt != nil {
                    Button { addStandardSchedule() } label: {
                        Label("Add the usual dates", systemImage: "calendar.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .accessibilityIdentifier("health.addSchedule")
                } else {
                    Text("Record the whelping date first — every one of these dates counts from it.")
                        .font(.caption).foregroundStyle(Theme.attention)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button { addingTask = true } label: {
                    Label("Add one event myself", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
            }
        }
    }

    private var gridCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tap a cell to mark it done").font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerRow
                        Divider()
                        ForEach(pups) { puppy in
                            puppyRow(puppy)
                            if puppy.id != pups.last?.id { Divider() }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("health.grid")
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("Puppy")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: nameColumnWidth, alignment: .leading)
            ForEach(tasks) { task in
                Button { editingTask = task } label: {
                    VStack(spacing: 2) {
                        Text(task.shortName)
                            .font(.caption2.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(task.dueDate.formatted(.dateTime.day().month(.abbreviated)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: cellWidth)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func puppyRow(_ puppy: Puppy) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(puppy.displayName)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text(puppy.sex.shortLabel)
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: nameColumnWidth, alignment: .leading)
            .padding(.vertical, 8)

            ForEach(tasks) { task in
                let done = task.isDone(for: puppy)
                Button { toggle(task: task, puppy: puppy) } label: {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(done ? Theme.accent : Color.secondary.opacity(0.45))
                        .frame(width: cellWidth, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(puppy.displayName), \(task.shortName), \(done ? "done" : "not done")")
                .accessibilityIdentifier("cell.\(puppy.birthOrder).\(task.sortIndex)")
            }
        }
    }

    private var productsCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("What was given").font(.headline)
                ForEach(tasks) { task in
                    Button { editingTask = task } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.shortName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(task.product.isEmpty ? "Product not recorded" : task.product)
                                    .font(.caption)
                                    .foregroundStyle(task.product.isEmpty ? Theme.attention : .secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            StagePill(text: "\(task.doneCount) of \(pups.count)", color: Theme.deep)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if task.id != tasks.last?.id { Divider() }
                }
                Text("Record the product your vet chose. Whelp Book does not recommend a product and never computes a dose.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func toggle(task: HealthTask, puppy: Puppy) {
        if let existing = puppy.wasGiven(task) {
            context.delete(existing)
        } else {
            let record = HealthGiven(givenOn: .now)
            record.task = task
            record.puppy = puppy
            context.insert(record)
            ReviewPrompter.recordSuccess(request: requestReview)
        }
        try? context.save()
    }

    private func addStandardSchedule() {
        guard let whelpedAt = litter.whelpedAt else { return }
        for item in HealthSchedule.tasks(whelpedAt: whelpedAt) {
            let task = HealthTask(name: item.name, dueDate: item.dueDate, sortIndex: item.sortIndex)
            task.litter = litter
            context.insert(task)
        }
        try? context.save()
    }

    private func makeTask() -> HealthTask? {
        let task = HealthTask(name: "", dueDate: .now, sortIndex: tasks.count)
        task.litter = litter
        context.insert(task)
        try? context.save()
        return task
    }
}

struct HealthTaskEditorView: View {
    @Bindable var task: HealthTask
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Name, such as Worming 2", text: $task.name)
                    DatePicker("Due", selection: $task.dueDate, displayedComponents: .date)
                }
                Section {
                    TextField("Product", text: $task.product)
                    TextField("Notes", text: $task.notes, axis: .vertical).lineLimit(1...4)
                } header: {
                    Text("What the vet chose")
                } footer: {
                    Text("Type the product and strength exactly as your vet gave it. Whelp Book records it and prints it on the puppy's record; it does not suggest a product and does not compute a dose.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                Section {
                    Button("Delete this event", role: .destructive) {
                        context.delete(task)
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .navigationTitle(task.name.isEmpty ? "New event" : task.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { try? context.save(); dismiss() }.bold()
                }
            }
        }
    }
}
