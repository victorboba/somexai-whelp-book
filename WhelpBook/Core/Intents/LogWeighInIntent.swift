import AppIntents
import Foundation

/// "Log a weigh-in in Whelp Book" from Siri, Spotlight or the Shortcuts app.
///
/// It opens the app on whichever screen the active litter is actually on: the whelping log if she
/// has not whelped yet, the weigh-in round once the puppies are here. One phrase covers both,
/// because at the moment someone says it they are holding a puppy either way.
struct LogWeighInIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Weigh-In"
    static var description = IntentDescription("Opens Whelp Book on the active litter, ready to record.")
    static var openAppWhenRun = true

    static let pendingKey = "intent.openWeighIn"

    func perform() async throws -> some IntentResult {
        WidgetSnapshot.defaults.set(true, forKey: Self.pendingKey)
        return .result()
    }
}

struct WhelpBookShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWeighInIntent(),
            phrases: ["Log a weigh-in in \(.applicationName)", "Open the litter in \(.applicationName)"],
            shortTitle: "Log Weigh-In",
            systemImageName: "scalemass"
        )
    }
}
