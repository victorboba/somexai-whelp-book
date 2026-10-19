import SwiftUI
import SwiftData

@main
struct WhelpBook: App {
    @State private var entitlements = EntitlementStore()
    private let container: ModelContainer

    init() {
        let schema = Schema([Dam.self, HeatCycle.self, Litter.self, Puppy.self,
                             WeighIn.self, HealthTask.self, HealthGiven.self])
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: AppConfig.iCloudSyncEnabled ? .automatic : .none
        )
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetData") {
            Self.deleteEverything(in: container.mainContext)
        }
        if ProcessInfo.processInfo.arguments.contains("-sampleData"),
           (try? container.mainContext.fetchCount(FetchDescriptor<Dam>())) == 0 {
            SampleData.insert(into: container.mainContext)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(entitlements)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }

    /// Deletes in dependency order so a cascade never fires against an object already gone.
    static func deleteEverything(in context: ModelContext) {
        try? context.delete(model: HealthGiven.self)
        try? context.delete(model: HealthTask.self)
        try? context.delete(model: WeighIn.self)
        try? context.delete(model: Puppy.self)
        try? context.delete(model: Litter.self)
        try? context.delete(model: HeatCycle.self)
        try? context.delete(model: Dam.self)
        try? context.save()
    }
}
