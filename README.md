# CalorieCut

## Web app for iPhone and Android

The installable [CalorieCut web app](Web/README.md) works on iOS and Android, including offline diary logging after the first online visit. It does not require Apple membership or weekly signing refreshes. See the web guide for local development, free HTTPS hosting with GitHub Pages, Home Screen installation, and backup migration from the native app. The website must be published before installing it on your phone.

A native iPhone nutrition diary for iOS 17+, built with SwiftUI, SwiftData, Swift Charts, Observation/MVVM, and local UserNotifications. No packages, login, backend, analytics, API keys, CloudKit, or internet connection are required by the app.

## Install using Windows

You do not need to own a Mac. See **[WINDOWS_INSTALL.md](WINDOWS_INSTALL.md)** for the included GitHub Actions cloud build and local AltStore signing/installation. The workflow generates a real unsigned iPhone IPA only after its builds/tests pass; it has not been run from this workspace.

## Open and install on your iPhone

1. On a Mac with **Xcode 16 or newer**, unzip this folder and open **CalorieCut.xcodeproj**. Select the **CalorieCut** scheme.
2. Add your Apple ID in **Xcode → Settings → Accounts**.
3. Select the **CalorieCut app target → Signing & Capabilities**. Leave **Automatically manage signing** enabled, choose your **Personal Team** or developer team, and change the bundle identifier from `com.example.CalorieCut` to a unique value such as `com.yourname.CalorieCut`. There are no special capabilities to provision.
4. Connect an iPhone running iOS 17+, unlock it, trust the Mac, and enable **Settings → Privacy & Security → Developer Mode** when requested. Restart the phone if required.
5. Choose the iPhone as the run destination and press **⌘R**. If prompted on the phone, trust the developer in **Settings → General → VPN & Device Management**.
6. Finish onboarding. Example values are editable. The default calorie goal is 1,900 kcal and protein goal is 120 g; you can apply the calculated suggestion instead.

A free Personal Team can run the app on your own phone; free provisioning generally expires after seven days and may require rebuilding. Export a backup before deleting or reinstalling the app. Building/running an update with the same bundle identifier preserves the database. The app is offline after installation; Xcode may need internet to provision signing or download simulators.

## What is included

- Two-step profile onboarding after a welcome screen, Mifflin–St Jeor estimates, activity multipliers, safe deficit caps, and editable goals.
- Home calorie ring, macros, hydration, today's weight, tracking streak, provisional daily score, meals, notes, and manually entered steps.
- Food logging with per-serving values and quantity, editable date/time/category, edit/delete/duplicate/move/copy, swipe actions, and context menus.
- Searchable quick add, recent foods first, favorites, editable reusable foods, and 14 approximate sample foods.
- Reusable meals with multiple ingredients, individual quantities, editable composition, and one-tap meal logging.
- Water increments/custom amounts, removable water logs, optional weight/waist measurements, comparisons, and measurement history.
- Color-coded monthly calendar linked to the diary.
- Weight, waist, calorie, and protein charts; 7 days, 30 days, 3 months, and all-time filters; averages across logged days.
- Rule-based daily feedback, consistency scores, seven-day reports, and cautious weight-trend guidance using up to four weeks of measurements.
- Custom local reminder times for breakfast, lunch, dinner, water, weight, and daily review.
- Metric/imperial display and input, System/Light/Dark appearance, native JSON export/share/import, validated replacement restore, and full local deletion.
- Original app icon, privacy manifest, shared Xcode scheme, calculation/backup tests, SwiftData integration tests, and UI smoke tests.

## Data and calculation behavior

`AppStore` is the main-actor observable view model. It owns an injected `ModelContext` and publishes fetched state. Drafts keep edits separate until Save. Autosave is disabled; mutations explicitly save, and errors are surfaced. SwiftData uses a local Application Support store with CloudKit disabled. The directory is excluded from automatic device backups and protected until the first device unlock. Export a JSON copy regularly.

Food entry nutrition is a **per-serving snapshot**, multiplied by quantity. Editing or deleting a library food cannot alter history. Saved meals own food snapshots with a cascade delete rule; diary entries have no relationship to the library or saved meal. Deleting a saved meal therefore preserves logged entries. Daily totals are calculated from food and water records, not duplicated in stored summary rows.

Dates are grouped by the iPhone's current calendar/time zone. Travel or time-zone changes can change which local day contains a timestamp. Daily and historical reports use your **current goals**. Weekly/monthly averages exclude unlogged days; an entry does not certify that the diary is complete. Green calendar dots mean within ±10% of the current calorie target, yellow means other logged days at or below 125%, red means above 125%, and gray means no food data. Low intake is not rewarded as a perfect score. Streaks require only logging food.

Weight and waist are stored in kg/cm and converted for display/input. The requested weekly change is always shown in kg/week so its relationship to energy calculations remains explicit. Profile edits change estimates but do not silently replace measurement history; use Progress → Add measurement to log a new reading.

JSON backups are versioned, checked before import, and restored with a single SwiftData save. Restore replaces the diary; export first if needed. Internal UUIDs are regenerated during restore to avoid unique-attribute conflicts, and meal relationships are rebuilt from their snapshots. Reminder times restore, but enabled reminders restart **disabled** so an import does not silently schedule alerts or request system permission. Enable them again in Settings. JSON contains personal information and is not encrypted by the app.

## Verification

This project was authored on Linux, which cannot run Xcode, SwiftUI, SwiftData, an iOS simulator, or Apple signing. **The full iOS build, launch, persistence integration, UI tests, notification delivery, and device acceptance checklist are not verified here.** See `VERIFICATION.md` for checks actually performed. Do not treat the project as a signed or release-validated binary.

The calculation and JSON tests compile the same Foundation source files used in the iOS app:

```sh
swift test
```

On a Mac, run all included checks:

```sh
./Scripts/verify_on_mac.sh
```

The script builds the iOS simulator target and runs calculation, SwiftData, and UI tests on an available iPhone simulator. To select a particular installed simulator:

```sh
SIMULATOR_UDID=YOUR_SIMULATOR_UUID ./Scripts/verify_on_mac.sh
```

Alternatively use **⌘U** in Xcode. Complete `QA.md` on a simulator and physical phone before release. UI smoke tests use `--uitesting` to create an isolated in-memory database; regular launches always use persistent local storage. The disk persistence integration test creates and reopens a separate temporary store.

## TestFlight or an IPA

No IPA is included: this host has no Xcode/iOS SDK or Apple signing identity. On a Mac with a paid Apple Developer Program team, assign a unique App Store bundle identifier, select **Any iOS Device (arm64)**, then **Product → Archive**. In Organizer, choose **Distribute App → App Store Connect → Upload**. Create the matching App Store Connect app record and add TestFlight testers after processing. Complete Apple's export-compliance, privacy, and health-related metadata accurately. For an installable exported IPA, use Organizer's appropriate development/ad hoc distribution option with certificates and eligible registered devices; a Personal Team is intended for direct Xcode installation.

## Layout

```text
CalorieCut.xcodeproj/       App + unit tests + UI tests; shared scheme
CalorieCut/
  App/                     App lifecycle and root tabs
  Models/                  SwiftData models and typed enums
  ViewModels/              Observable store and persistence actions
  Services/                Nutrition, reviews, backup, sample foods, reminders
  Utilities/               Validated drafts, model adapters, units, formatting
  Components/              Cards, ring, reusable fields and meal section
  Views/                   Onboarding, Home, Diary, AddFood, Progress, Review, Settings
  Resources/               Assets, Info.plist, privacy manifest
CalorieCutTests/            Calculation, backup, and SwiftData integration tests
CalorieCutUITests/          Onboarding, entry, calendar, and tab smoke tests
Package.swift              Foundation-only cross-platform test target
Scripts/                   Project generator and validation commands
```

No design tool or Figma file is required. The checked-in project is ready to open directly; the deterministic Python generator is optional when adding files. The calorie thresholds and feedback are general estimates for adults, not a medical diagnosis or a guarantee that any target is suitable for a particular person.
