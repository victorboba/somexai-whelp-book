import SwiftUI
import SwiftData

/// The details of one puppy, taken straight after the birth on targets big enough to hit without
/// looking. Everything on it is optional: the puppy already exists, this only fills it in.
struct PuppyQuickEntryView: View {
    @Bindable var puppy: Puppy
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("weights.unit") private var unitRaw = WeightUnit.grams.rawValue

    @State private var weightText = ""
    @FocusState private var weightFocused: Bool

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .grams }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    bornAtCard
                    sexCard
                    weightCard
                    identityCard
                    placentaCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .whelpBackground()
            .navigationTitle("Puppy \(puppy.birthOrder)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }.bold()
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { weightFocused = false }
                }
            }
            .onAppear {
                if puppy.birthWeightGrams > 0 {
                    weightText = unit == .grams
                        ? String(Int(puppy.birthWeightGrams.rounded()))
                        : String(format: "%.1f", WeightMath.ounces(fromGrams: puppy.birthWeightGrams))
                }
            }
        }
    }

    private var bornAtCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Time born").font(.headline)
                DatePicker("Time born", selection: $puppy.bornAt)
                    .labelsHidden()
                Stepper("Birth order: \(puppy.birthOrder)", value: $puppy.birthOrder, in: 1...30)
                    .font(.subheadline)
            }
        }
    }

    private var sexCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Sex").font(.headline)
                HStack(spacing: 10) {
                    ForEach(PuppySex.allCases) { option in
                        Button { puppy.sex = option } label: {
                            Text(option.label)
                                .font(.subheadline.weight(puppy.sex == option ? .bold : .regular))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(puppy.sex == option ? Theme.accent.opacity(0.22) : Color(.secondarySystemFill),
                                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(puppy.sex == option ? Theme.deep : Color.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("sex.\(option.rawValue)")
                    }
                }
            }
        }
    }

    private var weightCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Birth weight").font(.headline)
                    Spacer()
                    Picker("Unit", selection: $unitRaw) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.label).tag(unit.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                }
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .focused($weightFocused)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 68)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityIdentifier("puppy.birthWeight")
                if let grams = WeightMath.parse(weightText, unit: unit) {
                    Text(WeightMath.bothUnits(grams))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var identityCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Telling them apart").font(.headline)
                TextField("Collar or ribbon colour", text: $puppy.collar)
                    .textFieldStyle(.roundedBorder)
                TextField("Colour and markings", text: $puppy.markings, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                TextField("Name, if it has one yet", text: $puppy.name)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var placentaCard: some View {
        WhelpCard {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $puppy.placentaPassed) {
                    Text("Placenta passed").font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .tint(Theme.accent)
                .accessibilityIdentifier("puppy.placenta")
                Text("Counted because one left behind is the thing you want to have written down, not remembered.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                TextField("Anything else about this birth", text: $puppy.notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
            }
        }
    }

    private func save() {
        if let grams = WeightMath.parse(weightText, unit: unit) {
            puppy.birthWeightGrams = grams
        } else if weightText.trimmingCharacters(in: .whitespaces).isEmpty {
            puppy.birthWeightGrams = 0
        }
        try? context.save()
        dismiss()
    }
}
