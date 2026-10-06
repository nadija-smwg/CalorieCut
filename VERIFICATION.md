# Verification record

Authoring environment: Debian Linux; Swift 6.0.3 Linux toolchain installed for calculation checks. No Xcode or Apple SDK is present.

Performed:

- Built the Foundation-only Swift package using the same source files as the iOS app.
- **27 XCTest cases passed, zero failures**: BMR, all activity multipliers/TDEE, moderate target, minimum/capped deficit, gain target, arithmetic, daily/macronutrient/water/category totals, local-day isolation, daily scores, empty/low/high intake feedback, seven-day averages/counts, weight advice, calendar-day streaks including DST, unit round trips, input validation, JSON schema round trip, duplicate IDs, malformed/oversized/unsupported backups, invalid records, and reminder preference serialization.
- Swift compiler `-frontend -parse` on every Swift source file; no syntax errors.
- Additional Tree-sitter Swift syntax inspection; no syntax errors.
- Parsed the Xcode OpenStep project and verified targets, project-file references, source membership, shared scheme references, XML/plist files, and asset files.
- Supplementary Foundation type audit of model initializers/adapters/store/backup service using stripped SwiftData annotations and nonfunctional API stubs: passed. This is only a type audit; it does not simulate database behavior or validate SwiftData macros.
- Inspected application code for backend/network dependencies, TODO/fatal-error placeholders, and missing core implementations.

Not performed:

- Full iOS type checking/linking/building or compiler warning inspection against the Apple SDK.
- Actual SwiftData integration tests (12 included), UserNotifications request-construction tests (4 included), or UI smoke tests (3 included).
- Simulator launch, visual/accessibility/device QA, real database restart verification, or notification permission/delivery.
- Signing, archiving, installation, IPA export, or TestFlight submission.

The project is a complete source delivery, not a verified installable binary. Run `Scripts/verify_on_mac.sh` and complete `QA.md` before relying on release readiness. No IPA has been fabricated.

Windows follow-up: added `.github/workflows/build-iphone.yml`, `Scripts/build_unsigned_ipa.sh`, and `WINDOWS_INSTALL.md`. Shell/YAML/static checks are local-only. The workflow has not been uploaded or executed and no device IPA has been generated here.
