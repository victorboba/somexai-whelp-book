import SwiftUI
import SwiftData
import Charts

/// One puppy, end to end — and the screen the export button lives on, because the record the new
/// owner walks out with is the reason a breeder buys this app rather than using a spreadsheet.
struct PuppyDetailView: View {
    @Bindable var puppy: Puppy
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview
    @AppStorage("weights.unit") private var unitRaw = WeightUnit.grams.rawValue

    @State private var weighing = false
    @State private var editing = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .grams }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                identityCard
                weightCard
                historyCard
                healthCard
                buyerCard
                exportCard
                DisclaimerNote()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .whelpBackground()
        .navigationTitle(puppy.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { editing = true } label: { Label("Edit this puppy", systemImage: "pencil") }
                    Button { weighing = true } label: { Label("Weigh in", systemImage: "scalemass") }
                    Button { exportRecord() } label: { Label("Export puppy record", systemImage: "doc.richtext") }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $weighing) {
            WeighInSheet(puppy: puppy) { ReviewPrompter.recordSuccess(request: requestReview) }
        }
        .sheet(isPresented: $editing) { PuppyEditorView(puppy: puppy) }
        .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK") { exportError = nil }
        } message: { Text(exportError ?? "") }
    }

    private var identityCard: some View {
        WhelpCard(tint: Theme.accent.opacity(0.12), stroke: Theme.accent.opacity(0.28)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 14) {
                    if let data = puppy.photoData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(puppy.displayName).font(.title3.bold())
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(puppy.sex.label) · born \(puppy.bornAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(LitterTimeline.weeksLabel(puppy.ageInDays())) old · number \(puppy.birthOrder) of the litter")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                if !puppy.markings.isEmpty {
                    Text(puppy.markings).font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !puppy.microchip.isEmpty {
                    Text("Microchip \(puppy.microchip)").font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var weightCard: some View {
        WhelpCard(stroke: puppy.weightConcern == nil ? .clear : Theme.attention.opacity(0.45)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Weight").font(.headline)
                    Spacer()
                    if let latest = puppy.latestWeightGrams {
                        Text(WeightMath.bothUnits(latest))
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                            .accessibilityIdentifier("puppy.latestWeight")
                    }
                }
                if let concern = puppy.weightConcern {
                    StagePill(text: concern.label, color: Theme.attention, symbol: "exclamationmark.triangle.fill")
                    Text(concern.detail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if puppy.birthWeightGrams > 0 {
                    Text("Born at \(WeightMath.bothUnits(puppy.birthWeightGrams))")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let percent = puppy.percentOfBirthWeight, puppy.weightSamples.count > 1 {
                    Text(String(format: "Now %.0f%% of birth weight", percent))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let gain = WeightMath.averageDailyGain(puppy.weightSamples) {
                    Text("Averaging \(WeightMath.changeString(gain)) a day across the record")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if puppy.weightSamples.count >= 2 {
                    Chart(puppy.weightSamples) { sample in
                        LineMark(x: .value("Date", sample.date),
                                 y: .value("Weight", unit == .grams ? sample.grams : WeightMath.ounces(fromGrams: sample.grams)))
                            .foregroundStyle(Theme.accent)
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Date", sample.date),
                                  y: .value("Weight", unit == .grams ? sample.grams : WeightMath.ounces(fromGrams: sample.grams)))
                            .foregroundStyle(sample.isBirthWeight ? Theme.badge : Theme.accent)
                    }
                    .frame(height: 170)
                }
                Button { weighing = true } label: {
                    Label("Weigh in", systemImage: "scalemass").frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .accessibilityIdentifier("puppy.weighIn")
            }
        }
    }

    private var historyCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Weight history").font(.headline)
                if puppy.weightSamples.isEmpty {
                    Text("Nothing recorded yet.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(puppy.weightSamples.enumerated().reversed()), id: \.offset) { index, sample in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sample.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                                if sample.isBirthWeight {
                                    Text("Birth weight").font(.caption2).foregroundStyle(Theme.badge)
                                }
                            }
                            Spacer(minLength: 8)
                            Text(WeightMath.bothUnits(sample.grams))
                                .font(.subheadline.weight(.medium)).monospacedDigit()
                            if index > 0 {
                                let change = sample.grams - puppy.weightSamples[index - 1].grams
                                Text(WeightMath.changeString(change))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(change >= WeightMath.tolerance ? Theme.accent : Theme.attention)
                                    .frame(width: 62, alignment: .trailing)
                            }
                        }
                        if index > 0 { Divider() }
                    }
                }
            }
        }
    }

    private var healthCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Given").font(.headline)
                let tasks = puppy.litter?.healthTasks ?? []
                if tasks.isEmpty {
                    Text("No worming or vaccination dates set for this litter yet.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(tasks) { task in
                        HStack(alignment: .top) {
                            Image(systemName: task.isDone(for: puppy) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.isDone(for: puppy) ? Theme.accent : Color.secondary.opacity(0.5))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.shortName).font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(task.product.isEmpty ? "Product not recorded" : task.product)
                                    .font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            Text((puppy.wasGiven(task)?.givenOn ?? task.dueDate).formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if task.id != tasks.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private var buyerCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Buyer").font(.headline)
                TextField("Buyer name", text: $puppy.buyerName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("puppy.buyerName")
                TextField("Phone or email", text: $puppy.buyerContact)
                    .textFieldStyle(.roundedBorder)
                Toggle("Deposit paid", isOn: $puppy.depositPaid).tint(Theme.accent)
                if puppy.depositPaid {
                    HStack {
                        Text("Deposit amount")
                        Spacer()
                        TextField("0", value: $puppy.depositAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                    }
                }
                DatePicker("Goes home", selection: Binding(
                    get: { puppy.goHomeDate ?? puppy.litter?.goHomeDate ?? Date.now },
                    set: { puppy.goHomeDate = $0 }), displayedComponents: .date)
                Toggle("Gone home", isOn: $puppy.placed).tint(Theme.accent)
                    .accessibilityIdentifier("puppy.placed")
                TextField("Notes about the buyer", text: $puppy.buyerNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
            }
            .onChange(of: puppy.placed) { try? context.save() }
            .onChange(of: puppy.depositPaid) { try? context.save() }
        }
    }

    private var exportCard: some View {
        WhelpCard(tint: Theme.badge.opacity(0.14), stroke: Theme.badge.opacity(0.4)) {
            VStack(alignment: .leading, spacing: 10) {
                Text("The record they go home with").font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Identification, birth details, the whole weight history and everything the vet gave it, on one PDF. Print it or send it from the share sheet.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button { exportRecord() } label: {
                    Label("Export puppy record", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.deep)
                .accessibilityIdentifier("puppy.export")
            }
        }
    }

    private func exportRecord() {
        do {
            try? context.save()
            exportFile = ExportFile(url: try PDFExporter.exportPuppy(puppy))
        } catch {
            exportError = error.localizedDescription
        }
    }
}

/// Full edit of one puppy, for the morning after the whelping when the collar comes off and the
/// name goes on.
struct PuppyEditorView: View {
    @Bindable var puppy: Puppy
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section("Identification") {
                    TextField("Name", text: $puppy.name)
                    TextField("Collar or ribbon colour", text: $puppy.collar)
                    TextField("Colour and markings", text: $puppy.markings, axis: .vertical).lineLimit(1...4)
                    TextField("Microchip number", text: $puppy.microchip)
                    ChoiceChips(options: PuppySex.allCases,
                                selection: Binding(get: { puppy.sex }, set: { puppy.sex = $0 }),
                                title: { $0.label },
                                tint: { _ in Theme.accent })
                }
                Section("Birth") {
                    DatePicker("Time born", selection: $puppy.bornAt)
                    Stepper("Birth order: \(puppy.birthOrder)", value: $puppy.birthOrder, in: 1...30)
                    Toggle("Placenta passed", isOn: $puppy.placentaPassed)
                }
                Section("Photo") {
                    PhotoField(data: $puppy.photoData, label: "Photo of the puppy", maxSide: 900)
                }
                Section("Notes") {
                    TextEditor(text: $puppy.notes).frame(minHeight: 90)
                }
                Section {
                    Button("Delete this puppy", role: .destructive) {
                        context.delete(puppy)
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .navigationTitle(puppy.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { try? context.save(); dismiss() }.bold()
                }
            }
        }
    }
}
