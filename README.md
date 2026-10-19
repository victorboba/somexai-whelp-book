# Whelp Book

A breeding record that follows one litter from the dam's season to the day the last puppy leaves: matings, the whelping night, daily puppy weights, worming and vaccinations, buyers, and a go-home record. It is for small dog breeders.

One of a set of niche iPhone apps built from a shared SwiftUI template ([somexai-ios-template](https://github.com/victorboba/somexai-ios-template)). It was never released on the App Store; the code is here for anyone to use. The other apps are collected in [somexai-ios-apps](https://github.com/victorboba/somexai-ios-apps).

## What it does

- **Dams**: name, with optional breed, date of birth, registration and photo. Each season is recorded, and after the second one the app measures her own interval and projects the next from it.
- **Litters**: stud, mating dates and an optional ovulation date, with a due window that says what it counted from.
- **Whelping log**: one big Puppy born button, then sex, collar color, birth weight and whether the placenta came, built for one-handed use at night.
- **Weights**: daily weigh-ins in grams or ounces with charts. Any puppy whose weight did not go up since the last weigh-in is flagged Needs attention.
- **Health grid**: one row per puppy and one column per worming or vaccination event; tap a cell to mark it done and type the product your vet chose.
- **Buyers**: name, contact, deposit and go-home date, and a Placed status.
- **Export**: a go-home PDF per puppy (identification, birth details, weight history, treatments), a litter report, and a CSV of every weigh-in.
- Widget showing the active litter's stage and what is next, and a How do I use this app guide.

## The boundary

The app records what you and your vet enter. It does not give veterinary advice, diagnose anything, or recommend a product or a dose. The disclaimer appears on the weight screen, the health grid and every export.

## Privacy

Data stays on the device in SwiftData. There is no account, no analytics and no network access; iCloud sync is off (`iCloudSyncEnabled = false`). CSV and PDF files leave the device only when you share them.

## Build and run

Requirements: Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), and iOS 17 or later.

```bash
xcodegen generate
open WhelpBook.xcodeproj
```

Pick the `WhelpBook` scheme and an iPhone simulator, then Run.

Tests:

```bash
xcodebuild -scheme WhelpBook -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test
```

`scripts/ci.sh WhelpBook` is an alternative.

Paywall: the app has a hard paywall (annual subscription or lifetime purchase). Running from Xcode uses the bundled `Products.storekit` file, so purchases are simulated and free. Debug builds can also skip it with the `-unlock` launch argument or the Debug switch in Settings.

To run on your own device or ship it:

- Set your team in `project.yml` (`DEVELOPMENT_TEAM`).
- Change the `com.example` bundle ID prefix in `project.yml`, both `.entitlements` files and `Products.storekit`.
- Update `supportEmail`, `privacyPolicyURL` and `appStoreID` in `Shared/AppConfig.swift`.

## Notes for developers

- `Gestation`, `HeatHistory`, `LitterTimeline` and `WeightMath` in `Core/Domain` hold the date and weight logic without SwiftUI so it can be tested directly.

## Project layout

- `WhelpBook/App/`: app entry point and `RootView`, the single gate (onboarding, paywall, app).
- `WhelpBook/Core/`: `Domain/` (gestation, season history, timeline, weight math), CSV/PDF export, photo field, StoreKit entitlement store, App Intents, review prompt, sample data, shared UI.
- `WhelpBook/Features/`: Home, Dams, Litter (whelping, weights, health grid, buyers, puppy detail), Settings, Help, Onboarding, Paywall.
- `WhelpBook/Models/`: `Dam`, `Litter`, `Puppy`, `HealthTask`.
- `WhelpBookWidget/`: home screen widget reading a snapshot from the App Group.
- `WhelpBookTests/`, `WhelpBookUITests/`: unit tests and screenshot UI tests.
- `Shared/AppConfig.swift`: everything that changes per app (name, copy, product IDs, links, onboarding, how-to guide).
- App Shortcut: "Log a weigh-in in Whelp Book".

## License

MIT. See [LICENSE](LICENSE).
