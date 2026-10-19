import SwiftUI
import SwiftData

/// Every dam on file. Short screen on purpose: a hobby breeder has one to three girls, and the
/// interesting part is inside each of them.
struct DamsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Dam.name) private var dams: [Dam]
    @State private var editingDam: Dam?

    var body: some View {
        Group {
            if dams.isEmpty {
                ContentUnavailableView {
                    Label("No dams yet", systemImage: "pawprint")
                } description: {
                    Text("Add her once. Her seasons, her intervals and every litter she has had stay with her.")
                } actions: {
                    Button("Add a dam") { addDam() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                }
            } else {
                List {
                    ForEach(dams) { dam in
                        NavigationLink(value: WhelpDestination.dam(dam)) {
                            DamRow(dam: dam)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Dams")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { addDam() } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add a dam")
            }
        }
        .sheet(item: $editingDam) { DamEditorView(dam: $0) }
    }

    private func addDam() {
        let dam = Dam()
        context.insert(dam)
        try? context.save()
        editingDam = dam
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets { context.delete(dams[index]) }
        try? context.save()
    }
}

private struct DamRow: View {
    let dam: Dam

    var body: some View {
        HStack(spacing: 12) {
            DamAvatar(dam: dam, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(dam.displayName)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if !dam.breed.isEmpty {
                    Text(dam.breed).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(seasonsLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }

    private var seasonsLine: String {
        let seasons = dam.seasons.count
        let litters = dam.litterList.count
        let seasonText = seasons == 1 ? "1 season" : "\(seasons) seasons"
        let litterText = litters == 1 ? "1 litter" : "\(litters) litters"
        return "\(seasonText) · \(litterText)"
    }
}

struct DamAvatar: View {
    let dam: Dam
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let data = dam.photoData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.accent.opacity(0.18)
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
