import SwiftUI

/// The look that separates Whelp Book from the rest of the shelf: a plum accent, a warm amber for
/// the one thing that needs attention, and cards on a tinted ground rather than a grouped list.
enum Theme {
    static let accent = Color(red: 0.541, green: 0.310, blue: 0.580)
    static let deep = Color(red: 0.420, green: 0.247, blue: 0.431)
    static let badge = Color(red: 0.949, green: 0.718, blue: 0.020)
    static let attention = Color(red: 0.820, green: 0.420, blue: 0.110)

    /// The colour of a stage on the rail: plum for done, amber for now, grey for later.
    static func stageColor(_ stage: LitterStage, current: LitterStage, completed: Set<LitterStage>) -> Color {
        if stage == current { return badge }
        if completed.contains(stage) { return accent }
        return Color.secondary.opacity(0.35)
    }
}

/// The card the whole app is built from. A rounded, filled panel on a tinted ground reads as a
/// record book rather than as a settings screen, which is the point of not using a plain List here.
struct WhelpCard<Content: View>: View {
    var tint: Color = Color(.secondarySystemGroupedBackground)
    var stroke: Color = .clear
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(stroke, lineWidth: 1.5))
    }
}

/// A small capsule label. Wraps rather than truncating, because "Raising puppies" has to survive
/// the largest Dynamic Type setting whole (rule 18).
struct StagePill: View {
    let text: String
    var color: Color = Theme.accent
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.caption2) }
            Text(text).font(.caption.weight(.semibold))
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(color.opacity(0.16), in: Capsule())
        .foregroundStyle(color)
    }
}

/// The screen background. One tinted wash, used everywhere, so the app has a colour of its own the
/// moment it opens.
struct WhelpBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            LinearGradient(colors: [Theme.accent.opacity(0.10), Color(.systemGroupedBackground)],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
    }
}

extension View {
    func whelpBackground() -> some View { modifier(WhelpBackground()) }
}
