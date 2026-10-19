import SwiftUI
import SwiftData
import Charts

/// The morning round: every puppy weighed, in order, in one pass.
///
/// The reason the chart exists is the puppy that stops gaining, so that puppy is lifted to the top
/// of the screen rather than being left for the breeder to spot on a curve. What Whelp Book says
/// about it is deliberately flat — the weight did not go up — because saying anything more would be
/// a diagnosis, and this app does not make those.
struct WeightsView: View {
    @Bindable var litter: Litter
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview
    @AppStorage("weights.unit") private var unitRaw = WeightUnit.grams.rawValue

    @State private var weighing: Puppy?
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .grams }
    private var pups: [Puppy] { litter.pups }
    private var flagged: [Puppy] { pups.filter { $0.weightConcern != nil } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if pups.isEmpty {
                    WhelpCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No puppies yet").font(.headline)
                            Text("Record the litter on the whelping screen first. Birth weights become the first point on every curve.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    unitCard
                    if !flagged.isEmpty { attentionCard }
                    chartCard
                    ForEach(pups) { puppy in
                        PuppyWeightRow(puppy: puppy, unit: unit) { weighing = puppy }
                    }
                }
                DisclaimerNote()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .whelpBackground()
        .navigationTitle("Weights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { exportCSV() } label: { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Export weigh-ins as CSV")
                    .disabled(pups.isEmpty)
            }
        }
        .sheet(item: $weighing) { puppy in
            WeighInSheet(puppy: puppy) { ReviewPrompter.recordSuccess(request: requestReview) }
        }
        .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK") { exportError = nil }
        } message: { Text(exportError ?? "") }
    }

    private var unitCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Weigh-in unit").font(.subheadline.weight(.semibold))
                Picker("Unit", selection: $unitRaw) {
                    ForEach(WeightUnit.allCases) { unit in Text(unit.label).tag(unit.rawValue) }
                }
                .pickerStyle(.segmented)
                Text("Type in whichever your scale uses. Every weight is stored in grams and shown in both.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var attentionCard: some View {
        WhelpCard(tint: Theme.attention.opacity(0.12), stroke: Theme.attention.opacity(0.4)) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Needs your attention", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline).foregroundStyle(Theme.attention)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(flagged) { puppy in
                    if let concern = puppy.weightConcern {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(puppy.displayName) — \(concern.label)")
                                .font(.subheadline.weight(.medium))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(concern.detail)
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weights.attention")
    }

    private var chartCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Growth curves").font(.headline)
                let series = pups.flatMap { puppy in
                    puppy.weightSamples.map { (name: puppy.displayName, sample: $0) }
                }
                if series.count < 2 {
                    Text("Two weigh-ins and the curves appear. Weigh them at the same time each day so the numbers compare.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Chart {
                        ForEach(Array(series.enumerated()), id: \.offset) { _, point in
                            LineMark(
                                x: .value("Date", point.sample.date),
                                y: .value(unit == .grams ? "Grams" : "Ounces",
                                          unit == .grams ? point.sample.grams : WeightMath.ounces(fromGrams: point.sample.grams))
                            )
                            .foregroundStyle(by: .value("Puppy", point.name))
                            .interpolationMethod(.monotone)
                            PointMark(
                                x: .value("Date", point.sample.date),
                                y: .value(unit == .grams ? "Grams" : "Ounces",
                                          unit == .grams ? point.sample.grams : WeightMath.ounces(fromGrams: point.sample.grams))
                            )
                            .foregroundStyle(by: .value("Puppy", point.name))
                            .symbolSize(22)
                        }
                    }
                    .chartLegend(position: .bottom, spacing: 8)
                    .frame(height: 220)
                }
            }
        }
    }

    private func exportCSV() {
        do { exportFile = ExportFile(url: try CSVExporter.exportWeighIns(litter)) }
        catch { exportError = error.localizedDescription }
    }
}

private struct PuppyWeightRow: View {
    @Bindable var puppy: Puppy
    let unit: WeightUnit
    let weigh: () -> Void

    var body: some View {
        WhelpCard(stroke: puppy.weightConcern == nil ? .clear : Theme.attention.opacity(0.45)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        NavigationLink(value: WhelpDestination.puppy(puppy)) {
                            HStack(spacing: 5) {
                                Text(puppy.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        Text("\(puppy.sex.label) · \(puppy.weightSamples.count) weights")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        if let latest = puppy.latestWeightGrams {
                            Text(unit == .grams ? WeightMath.gramsString(latest) : WeightMath.ouncesString(latest))
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                                .monospacedDigit()
                            if let change = puppy.changeSinceLastWeighIn {
                                Text(WeightMath.changeString(change))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(change >= WeightMath.tolerance ? Theme.accent : Theme.attention)
                            }
                        } else {
                            Text("No weight yet").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if let concern = puppy.weightConcern {
                    StagePill(text: concern.label, color: Theme.attention, symbol: "exclamationmark.triangle.fill")
                }
                Button(action: weigh) {
                    Label("Weigh in", systemImage: "scalemass")
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .accessibilityIdentifier("weigh.\(puppy.birthOrder)")
            }
        }
    }
}

/// One weight, typed once. Kept to a single field so the round goes quickly.
struct WeighInSheet: View {
    @Bindable var puppy: Puppy
    var onSave: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("weights.unit") private var unitRaw = WeightUnit.grams.rawValue

    @State private var date = Date.now
    @State private var text = ""
    @State private var notes = ""
    @FocusState private var focused: Bool

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .grams }
    private var parsed: Double? { WeightMath.parse(text, unit: unit) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    WhelpCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Weight").font(.headline)
                                Spacer()
                                Picker("Unit", selection: $unitRaw) {
                                    ForEach(WeightUnit.allCases) { unit in Text(unit.label).tag(unit.rawValue) }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 170)
                            }
                            TextField("0", text: $text)
                                .keyboardType(.decimalPad)
                                .focused($focused)
                                .font(.system(size: 44, weight: .semibold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, minHeight: 74)
                                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .accessibilityIdentifier("weighin.value")
                            if let grams = parsed {
                                Text(WeightMath.bothUnits(grams)).font(.subheadline).foregroundStyle(.secondary)
                                if let previous = puppy.weightSamples.last {
                                    Text("Previous \(WeightMath.bothUnits(previous.grams)) · \(WeightMath.changeString(grams - previous.grams))")
                                        .font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    WhelpCard {
                        VStack(alignment: .leading, spacing: 10) {
                            DatePicker("When", selection: $date)
                            TextField("Notes", text: $notes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(1...3)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .whelpBackground()
            .navigationTitle(puppy.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.bold().disabled(parsed == nil)
                }
            }
            .onAppear { focused = true }
        }
    }

    private func save() {
        guard let grams = parsed else { return }
        let weighIn = WeighIn(date: date, grams: grams, notes: notes)
        weighIn.puppy = puppy
        context.insert(weighIn)
        try? context.save()
        onSave()
        dismiss()
    }
}
