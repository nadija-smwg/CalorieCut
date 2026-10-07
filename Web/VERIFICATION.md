# Web app verification

Checked on 2026-10-07 in the Linux cloud environment. The core web workflows pass the checks below. This is not a claim that the site is published or that installation has been tested on physical phones.

## Results

| Check | Result |
| --- | --- |
| Foundation rules, validation, dates, units, reviews, backups, and daily aggregation | **20 unit tests passed**, zero failures |
| Same unit suite in America/New_York, including calendar/DST behavior | **20 passed**, zero failures; repeat run, not additional cases |
| Desktop and mobile browser workflows | **36 passed**, zero failures, skipped, or expected failures |
| Production build | Passed; static app shell, manifest, icons, and versioned service worker generated |
| Production preview | Started successfully; all ten production artifacts returned HTTP 200 and matched the built files byte for byte |
| Native/web backup interoperability | Actual Swift `BackupCodec` accepted the web JSON and re-encoded it; the web decoder accepted the Swift JSON |
| Automated accessibility | All five screens, dark Settings, and profile dialog passed the enabled WCAG 2.0/2.1 A/AA axe checks on desktop and mobile |
| Dependency audit | Zero known vulnerabilities reported by `npm audit` at the time of this check |
| GitHub Actions workflows | Both web and native workflows pass actionlint 1.7.12; web push/PR validation, manual-only deployment, browser diagnostics, artifact paths, and permissions checked locally |
| Native project structure | Existing structural check passed; native app source unchanged |

The final browser run uses `CI=1 CHROMIUM_PATH=/usr/bin/chromium`, system Chromium 151.0.7922.173 with Playwright 1.63.0, desktop 1440×1000 and mobile 390×844 layouts, and the Asia/Colombo time zone. This verifies CI's fresh preview-server startup, focused-test guard, and HTML reporter with an explicit local browser override. The GitHub runner's browser installation and WebKit execution remain unverified here. Earlier layout inspection also verified all five screens at 320, 390, 768, and 1440 pixels wide. Automated accessibility checks do not replace a manual screen-reader and usability review.

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

## Still outstanding

1. **Safari/WebKit execution:** the browser binary download returned HTTP 403 `Domain forbidden` for `cdn.playwright.dev` and `playwright.download.prss.microsoft.com`. Additions for these two domains are saved in the cloud environment draft. Review and save the network changes in environment settings, then publish the environment. Once runtime access is available, install WebKit and run:

   ```sh
   cd /workspace/CalorieCut/Web
   PLAYWRIGHT_BROWSERS_PATH=/workspace/.toolchains/playwright npx --cache /workspace/.toolchains/npm-cache playwright install --with-deps webkit
   PLAYWRIGHT_BROWSERS_PATH=/workspace/.toolchains/playwright CALORIECUT_WEBKIT=1 npm run test:e2e
   ```

   These WebKit commands are **not verified here** because download access is blocked. The GitHub Pages workflow installs Chromium and WebKit and enables the Safari project before deploying, but that workflow has not been executed.

2. **Live HTTPS deployment:** source changes have not been pushed and the Pages workflow has not run. Follow [the deployment guide](README.md#publish-free-with-github-pages). Publishing the cloud environment is separate from publishing the website.

3. **Physical iPhone and Android acceptance:** install from Safari and Chrome, launch from the icon, log food/water, force-close/reopen, test airplane mode, and export/import a backup. Confirm text size, keyboard/date-picker behavior, and VoiceOver/TalkBack usability on the actual devices.

## Intentional limits

No automatic device sync or scheduled notifications while the app is closed. Data is local to the browser/installation, can be cleared or evicted by the browser, and should be backed up regularly. Use the phone's Clock or Calendar for repeating reminders. These are documented product limits, not passing checks for features that are absent.
