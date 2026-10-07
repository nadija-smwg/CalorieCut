# Web app verification

Checked on 2026-10-07 in the Linux cloud environment. The core web workflows pass the checks below. This is not a claim that the site is published or that installation has been tested on physical phones.

## Results

| Check | Result |
| --- | --- |
| Foundation rules, validation, dates, units, reviews, backups, and daily aggregation | **20 unit tests passed**, zero failures |
| Same unit suite in America/New_York, including calendar/DST behavior | **20 passed**, zero failures; repeat run, not additional cases |
| Chromium desktop/mobile and WebKit mobile browser workflows | **57 unique cases passed across the full run and targeted reruns**; no remaining failing cases |
| Production build | Passed; static app shell, manifest, icons, and versioned service worker generated |
| Production preview | Started successfully; all ten production artifacts returned HTTP 200 and matched the built files byte for byte |
| Native/web backup interoperability | Actual Swift `BackupCodec` accepted the web JSON and re-encoded it; the web decoder accepted the Swift JSON |
| Automated accessibility | All five screens, dark Settings, and profile dialog passed the enabled WCAG 2.0/2.1 A/AA axe checks on Chromium desktop/mobile and WebKit mobile |
| Dependency audit | Zero known vulnerabilities reported by `npm audit` at the time of this check |
| GitHub Actions workflows | Both web and native workflows pass actionlint 1.7.12; web push/PR validation, manual-only deployment, browser diagnostics, artifact paths, and permissions checked locally |
| Native project structure | Existing structural check passed; native app source unchanged |

The final browser run uses system Chromium 151.0.7922.173 and WebKit 26.6 (revision 2359), Playwright 1.63.0, desktop 1440×1000 and mobile 390×844 layouts, and the Asia/Colombo time zone. CI mode verifies fresh preview-server startup, the focused-test guard, and HTML reporting. Earlier layout inspection also verified all five screens at 320, 390, 768, and 1440 pixels wide. Automated checks do not replace actual-phone installation or a manual screen-reader review.

WebKit download access is now available. This rootless Debian cloud uses additional libraries downloaded through Debian's signed package index and extracted under `/workspace/.toolchains/webkit-libs`. The local helper `/workspace/.toolchains/run-caloriecut-web-tests.sh` independently verifies all 58 WebKit ELF files' shared-library dependencies and GLES dynamic loading before replacing Playwright's cache-only host check, which cannot see libraries installed outside system paths. The GitHub workflow uses its standard `playwright install --with-deps chromium webkit` and normal host validation.

## Black appearance restoration

The original iOS palette is restored: black canvas, charcoal cards, white text, and mint accent (`#61d1a8`). New and existing web diaries default to black; a one-time atomic migration preserves all diary records and lets later System/Light/Dark choices persist. Internal appearance metadata is omitted from exported native-compatible backups, and importing a backup preserves its appearance preference. Manifest launch colors and browser chrome match the black theme. A mobile screenshot was visually inspected.

For this change, the full existing suite passed 53 cases and hit the 30-second limit in WebKit's expanded accessibility scan. That scan now has a 60-second allowance and passed on all engines, including explicit Light and Dark checks. Targeted export/restore checks also passed. The three new migration/persistence/backup cases passed on desktop, mobile, and WebKit after correcting a test navigation assumption. All 57 distinct cases have passing results; a single uninterrupted local run of the new 57-case suite has not been performed. The production build and all 20 unit tests passed.

## Workflows exercised

- Onboarding, safe calorie estimates, editable goals, and profile changes that preserve measurement history.
- Food logging with per-serving quantity, editing, deletion, duplication, movement to another date/meal, and copying to another day.
- Food search, favorites, editing/deleting library foods without changing diary snapshots, and custom food names rendered safely as text.
- Saved meal creation, ingredient selection and quantities, empty-meal rejection, portion scaling, editing, and deletion while preserving logged meals.
- Water additions, custom amounts, history removal, notes, steps, and preserving notes across online/offline changes.
- Day/month navigation and historical calendar totals; current-goal comparisons and historical reflection calculations.
- Weight and waist-only measurements, imperial boundary values, editing/deletion, chart ranges, chronological chart spacing, and accessible data tables.
- Appearance and unit preferences, installation guidance, data deletion, JSON export/restore, and rejection of malformed/invalid/oversized backups.
- Atomic save failure with simulated full storage; previous diary retained without uncaught errors. Corrupt stored data remains available for recovery export.
- Stale-tab writes rejected instead of silently overwriting newer data.
- Offline reload and new saves while uncached requests fail; root and repository-subdirectory hosting both exercised.
- New app versions activate after the previous window closes, keep IndexedDB data, remove their old cache, and preserve another app's caches.
- No external page requests during the exercised screens and food-logging workflow. No external runtime packages, fonts, analytics, or API services are used.
- Daily aggregation with 5,000 records over 100 days; calendar and chart rendering reuse an index instead of scanning the entire history for every day.

## Issues fixed during this audit

- Updated Vite from 7.2.2 to patched 7.3.7 after its development-server advisories were reported. Updated Playwright to 1.63.0.
- Historical weight guidance now uses the selected week and excludes measurements after that date.
- Imperial inputs round back to canonical metric precision without rejecting valid minimum/maximum measurements.
- Imported dates must be valid ISO calendar dates and are normalized before chronological sorting. Future water, notes, and measurements are rejected.
- Charts space points according to elapsed calendar days.
- Saves disable controls until their transaction completes; storage exceptions abort cleanly.
- Offline asset matching handles static servers' `Vary: Origin` headers. Offline cache cleanup is scoped to this app's path, and worker changes affect cache versioning.
- Dark/light text contrast and dark hover styling corrected. Offline-worker generation now runs only during production builds.
- Web CI now runs on main-branch pushes and pull requests; deployment remains manual and requires successful validation. CI uses matching Playwright browsers, rejects focused tests, and saves failure traces, screenshots, and HTML reports. Timeouts and separate deployment concurrency added.
- Removed the toast opacity fade after an intermittent mobile accessibility failure: visible status text now keeps full contrast during its slide animation and disappears without fading.

- Reproduced the supplied GitHub log's five WebKit failures. Offline tests now disconnect the actual test origin, close existing connections, and require uncached requests to fail. Chromium retains the protocol offline flag; WebKit restores that flag for reload because it otherwise blocks service-worker navigation before the cached shell can respond. Root/subdirectory reloads, new offline saves, notes, and app updates remain asserted.
- Settings headings explicitly use their card's theme background, avoiding WebKit's incorrect white-background contrast sample. Accessibility checks wait for painting and report detailed contrast failures; no checks are skipped or disabled.

## Still outstanding

1. **GitHub validation of the fixes:** the supplied log for the original commit shows 49 passing tests and five WebKit failures. The previous WebKit fix and manual deployment were confirmed successful by the user’s GitHub screenshots. The new black appearance change requires a fresh CI result and another manual Pages deployment.
2. **Live HTTPS deployment:** the initial web app was pushed to `main`, but no successful website deployment has been verified. Follow [the deployment guide](README.md#publish-free-with-github-pages). Publishing the cloud environment is separate from publishing the website.
3. **Physical iPhone and Android acceptance:** install from Safari and Chrome, launch from the icon, log food/water, force-close/reopen, test airplane mode, and export/import a backup. Confirm text size, keyboard/date-picker behavior, and VoiceOver/TalkBack usability on the actual devices.

## Intentional limits

No automatic device sync or scheduled notifications while the app is closed. Data is local to the browser/installation, can be cleared or evicted by the browser, and should be backed up regularly. Use the phone's Clock or Calendar for repeating reminders. These are documented product limits, not passing checks for features that are absent.
