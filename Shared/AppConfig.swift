import Foundation

/// The one file to edit when starting a new app from this template.
/// Everything user-facing that changes per app (name, copy, product IDs, links) lives here.
/// Compiled into both the app and the widget, so keep it free of UIKit/SwiftUI imports.
enum AppConfig {
    // MARK: Identity
    static let appName = "Whelp Book"
    static let bundleID = "com.example.whelp-book"
    static let appGroupID = "group.com.example.whelp-book"
    /// Your App Store ID once the app is live. The Rate button stays hidden while it is empty.(the number in the App Store URL).
    static let appStoreID = ""

    // MARK: Sync
    /// Set to true only after enabling iCloud + CloudKit on the App ID (see docs/capabilities.md).
    /// With false, SwiftData stores locally and the app works with no Apple capabilities at all.
    static let iCloudSyncEnabled = false

    // MARK: StoreKit (must match App Store Connect and StoreKit/Products.storekit)
    /// Apple allows only letters, digits, underscores and periods in product IDs, so hyphens in the bundle ID are dropped.
    static let productPrefix = bundleID.replacingOccurrences(of: "-", with: "")
    static let annualProductID = "\(productPrefix).pro.annual"
    static let lifetimeProductID = "\(productPrefix).pro.lifetime"

    // MARK: Links
    static let supportEmail = "support@somexai.com"
    /// Hosted copy of PrivacyPolicyView, one page per app under somexai.com/privacy (somexai_corp repo, scripts/privacy.py).
    static let privacyPolicyURL = URL(string: "https://somexai.com/privacy/whelp-book/")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // MARK: Copy
    /// What the app calls one record. A litter is the spine; puppies and weigh-ins hang off it.
    static let entryNoun = "Litter"
    static let entryNounPlural = "Litters"
    /// File name stem for exports: "whelp-book-2026-09-14.pdf".
    static let exportFileStem = "whelp-book"

    /// The sentence that keeps the app on the right side of "record keeping, not veterinary advice".
    /// It goes on the weight screen, the health grid and every exported document.
    static let disclaimer = "Whelp Book records what you and your vet enter. It does not give veterinary advice, diagnose anything, or recommend a product or a dose."

    static let onboarding: [OnboardingPage] = [
        OnboardingPage(symbol: "point.topleft.down.to.point.bottomright.curvepath", title: "One record, not three",
                       body: "Her season, the matings, the whelping night and every puppy's weight live on one timeline instead of in a calendar app, a notebook and a spreadsheet."),
        OnboardingPage(symbol: "moon.stars", title: "Built for three in the morning",
                       body: "The whelping screen is one big button. Time, order, sex, colour, weight and the placenta, in seconds, one-handed, in bad light."),
        OnboardingPage(symbol: "chart.line.uptrend.xyaxis", title: "The puppy that stopped gaining",
                       body: "Weigh them daily in grams or ounces. Whelp Book marks any puppy whose weight did not go up since the last weigh-in."),
        OnboardingPage(symbol: "doc.text", title: "The document they go home with",
                       body: "Export a record per puppy: identification, birth details, the whole weight history and what the vet gave it, and when."),
    ]

    static let paywallSymbol = "pawprint.circle.fill"
    static let paywallHeadline = "Unlock Whelp Book"
    static let paywallBenefits = [
        "Unlimited dams, litters and puppies",
        "Season intervals measured from her own history",
        "Whelping log and daily weight charts",
        "Worming and vaccination grid for the whole litter",
        "A go-home record per puppy as PDF, plus CSV",
        "No ads, no account, no tracking",
    ]

    // MARK: How-to guide (Settings → How do I use this app; also the ? button on the home screen)
    static let howToIntro = "Whelp Book follows one litter from her season to the day the last puppy leaves. Work down this list in order and the timeline fills itself in."
    static let howTo: [HowToStep] = [
        HowToStep(symbol: "pawprint", title: "Add the dam",
                  body: "Tap Dams in the toolbar, then Add a dam. Her name is all that is needed; breed, date of birth, registration and a photo can wait.",
                  tip: "One dam can hold years of seasons and several litters, so add her once and keep using her."),
        HowToStep(symbol: "calendar", title: "Record every season",
                  body: "Open the dam and tap Add a season with the day her season started. After the second season Whelp Book measures her own interval and projects the next one from it, instead of assuming six months."),
        HowToStep(symbol: "heart.circle", title: "Start the litter",
                  body: "From the dam, tap Start a litter. Fill in the stud's name, the mating dates, and the ovulation date if you had her tested. Whelp Book shows a due window and says what it counted from."),
        HowToStep(symbol: "moon.stars", title: "Whelp the litter",
                  body: "When she starts, tap Whelping on the home timeline. Each time one arrives tap the big Puppy born button, then set sex, collar colour, birth weight and whether the placenta came. Corrections can wait until morning.",
                  tip: "Say \"Log a weigh-in in Whelp Book\" to Siri to jump straight in without hunting for the app."),
        HowToStep(symbol: "scalemass", title: "Weigh them every day",
                  body: "Tap Weights on the timeline and enter each puppy in turn. Switch between grams and ounces at the top. Any puppy whose weight did not go up since the last weigh-in gets a Needs attention flag."),
        HowToStep(symbol: "cross.case", title: "Track worming and vaccinations",
                  body: "Tap Health, then Add the usual dates to lay out a grid of one row per puppy and one column per event. Tap a cell to mark it done, and type in the product your vet chose."),
        HowToStep(symbol: "house", title: "Buyers and go-home dates",
                  body: "Open a puppy and fill in the Buyer section: name, contact, deposit and the go-home date. Mark the puppy Placed once it has gone."),
        HowToStep(symbol: "square.and.arrow.up", title: "Hand over the record",
                  body: "On a puppy, tap Export puppy record for the PDF the new owner keeps. From the home screen, Export gives you the whole litter report or a CSV of every weigh-in."),
        HowToStep(symbol: "rectangle.on.rectangle", title: "Add the widget",
                  body: "Long-press your Home Screen, tap +, search \"Whelp Book\", and add the small or medium widget. It shows the active litter's stage and what is next."),
    ]

    /// Display prices used only by DEBUG screenshot runs (`-mockPrices`). Keep in sync with StoreKit/Products.storekit.
    static let mockPrices = (annual: "$6.99", lifetime: "$14.99")

    // MARK: Behaviour
    /// Ask for an App Store review after this many successful saves (once per app version).
    static let reviewAfterSuccesses = 3
}

struct HowToStep: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
    var tip: String? = nil
}

struct OnboardingPage: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
}
