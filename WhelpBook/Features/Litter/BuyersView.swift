import SwiftUI
import SwiftData

/// Who is taking which puppy, what they have paid, and when it leaves.
struct BuyersView: View {
    @Bindable var litter: Litter
    @Environment(\.modelContext) private var context

    @State private var editingGoHome = false
    @State private var goHomeDate = Date.now

    private var pups: [Puppy] { litter.pups }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCard
                if pups.isEmpty {
                    WhelpCard {
                        Text("No puppies yet. They appear here the moment they are recorded on the whelping screen.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    ForEach(pups) { puppy in
                        NavigationLink(value: WhelpDestination.puppy(puppy)) {
                            BuyerRow(puppy: puppy)
                        }
                        .buttonStyle(.plain)
                    }
                }
                DisclaimerNote()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .whelpBackground()
        .navigationTitle("Buyers")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editingGoHome) {
            NavigationStack {
                Form {
                    DatePicker("Go-home date for the litter", selection: $goHomeDate, displayedComponents: .date)
                    Text("Each puppy can still have its own date. This is the one the timeline counts to.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .navigationTitle("Go-home date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            litter.goHomeDate = goHomeDate
                            try? context.save()
                            editingGoHome = false
                        }.bold()
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var summaryCard: some View {
        WhelpCard(tint: Theme.accent.opacity(0.12), stroke: Theme.accent.opacity(0.28)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(pups.filter(\.placed).count) of \(pups.count) placed")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.deep)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(pups.filter(\.depositPaid).count) deposits taken · \(pups.filter { !$0.buyerName.isEmpty }.count) with a buyer named")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    goHomeDate = litter.goHomeDate ?? Calendar.current.date(byAdding: .day, value: 56, to: litter.whelpedAt ?? .now) ?? .now
                    editingGoHome = true
                } label: {
                    Label(litter.goHomeDate == nil ? "Set the go-home date" : "Go home \(litter.goHomeDate!.formatted(date: .abbreviated, time: .omitted))",
                          systemImage: "calendar")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
            }
        }
    }
}

private struct BuyerRow: View {
    let puppy: Puppy

    var body: some View {
        WhelpCard(stroke: puppy.placed ? Theme.accent.opacity(0.4) : .clear) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(puppy.displayName)
                            .font(.headline).foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(puppy.buyerName.isEmpty ? "No buyer yet" : puppy.buyerName)
                            .font(.subheadline)
                            .foregroundStyle(puppy.buyerName.isEmpty ? .secondary : .primary)
                            .fixedSize(horizontal: false, vertical: true)
                        if !puppy.buyerContact.isEmpty {
                            Text(puppy.buyerContact).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 6) {
                        if puppy.placed { StagePill(text: "Placed", color: Theme.accent, symbol: "checkmark") }
                        if puppy.depositPaid { StagePill(text: "Deposit", color: Theme.deep, symbol: "dollarsign") }
                    }
                }
                if let date = puppy.goHomeDate {
                    Text("Goes home \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundStyle(Theme.deep)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
