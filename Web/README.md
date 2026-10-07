# CalorieCut for iPhone and Android

An installable, offline web app alongside the native Swift app. No account, server database, API key, or signing certificate is required. There is no seven-day signing expiry.

## Run locally

Use Node.js 22.12+ or 24 and npm:

```sh
cd Web
npm ci
npm run dev
```

Production and validation:

```sh
npm test
npm run build
npm run test:e2e
npm run preview
```

Run these commands from `Web`. `npm run preview` starts a long-running production server; stop it with Ctrl+C when finished. Browser tests start and stop their own preview server on port 4173. Stop any manual preview on that port first: CI always starts its own server, while local tests can reuse a running one.

Local browser tests use system Chromium if available. Otherwise run `npx playwright install chromium` first. CI installs and uses the browser revision matching the locked Playwright version. `CHROMIUM_PATH` can select a specific Chromium executable in either mode. Tests cover desktop and mobile layouts; they do not replace testing Safari on an actual iPhone or Chrome on an Android phone.

For Safari-engine coverage, install Playwright WebKit with `npx playwright install --with-deps webkit`, then run `CALORIECUT_WEBKIT=1 npm run test:e2e`. The deployment workflow enables this project. WebKit coverage is now available in the cloud environment; see the current results and remaining release checks in [VERIFICATION.md](VERIFICATION.md).

Offline tests disconnect a dedicated production-file server and require uncached network requests to fail. Chromium also uses Playwright’s offline flag. WebKit’s flag blocks service-worker navigation in the test driver, so WebKit reloads use the disconnected server with its protocol online flag restored. Network-status events, persistence, and cached reloads are still checked.

Development mode does not register an offline worker. Test offline behavior against `npm run build` followed by `npm run preview`. The build generates a versioned offline cache containing the entire app shell. Updates activate after all tabs and installed windows using the previous version are closed. Data stays in IndexedDB across app updates.

## Publish free with GitHub Pages

The workflow checks web changes on pushes to `main` and on pull requests. Validation installs locked dependencies, runs unit tests, builds the production site, and tests Chromium desktop/mobile and WebKit mobile layouts. Failed runs upload browser reports, traces, and screenshots where available. Publication remains manually triggered and runs only after validation succeeds. No live deployment has been verified here.

1. Commit and push the web app and `.github/workflows/publish-web.yml` to GitHub.
2. In the GitHub repository, open **Settings → Pages**. Select **GitHub Actions** as the source.
3. Open **Actions → Publish CalorieCut web app → Run workflow**. Choose the branch containing the web app.
4. Wait for the build, tests, and deployment. Use the website address shown by the successful deployment or Pages settings.

GitHub Pages is free for public repositories; private repository availability depends on your GitHub plan. The site can also be hosted on any HTTPS static host: upload the contents of `Web/dist`. No server code is needed. Relative asset, manifest, and worker paths support hosting under a repository subdirectory. Keep the same website address to retain access to that origin’s diary.

## Install on your phone

Open the published HTTPS website while connected to the internet and wait for it to finish loading.

- **iPhone/iPad:** use Safari → Share → **Add to Home Screen**. If shown, leave “Open as Web App” enabled, then tap Add.
- **Android:** use Chrome → menu (⋮) → **Install app** or **Add to Home screen**.

Launch from the new icon once while online. Then try opening it in airplane mode. A modern browser with IndexedDB and service worker support is required. A development URL served over plain HTTP on another device will not provide installable offline behavior; use HTTPS for phone installation.

## Included

- Editable adult profile and calorie estimate with the native deficit/surplus safeguards.
- Calories, macros, hydration, logging streak, and calorie goals.
- Searchable food library, favorites, custom foods, per-serving nutrition, and approximate sample foods.
- Meal/date/time selection, edit/delete/duplicate/copy entries; create, edit, and log saved meals.
- Day navigation and monthly calendar, daily notes, and manually entered steps.
- Weight and waist measurements, editable history, accessible charts with data tables, and time filters.
- Daily reflection, seven-day averages excluding unlogged days, and cautious weight-trend guidance.
- Metric/imperial display and input; system, light, and dark themes.
- Validated JSON export/import compatible with the native CalorieCut version-1 format. Imported reminder settings restart disabled.
- Offline app shell and local IndexedDB storage. Saves are atomic; stale tabs cannot silently overwrite a newer diary.

## Data and practical limits

There is no automatic sync between phones, browsers, or installations. Export a backup and import it on another device to move your diary. Import replaces existing data after confirmation. Backups contain personal information and are not encrypted by the app.

Browser storage can be cleared or evicted. Export backups regularly, before uninstalling, clearing browser data, moving to a new website address, or changing phones. “Keep storage on this device” requests persistent browser storage where supported; the browser decides whether to grant it. Private browsing is unsuitable for a lasting diary. On iPhone, the installed app and browser may use separate storage; export/import if your existing diary does not appear after installation.

The web app does not schedule notifications while closed. Use your phone’s Clock or Calendar for repeating reminders. There is no push notification service or background server.

Dates are grouped using the device’s current time zone. Travel can change the local day for a timestamp. Reports use current goals. Nutrition samples are approximate and calorie estimates are general adult guidance, not medical advice.

## Files

`src/core.js` contains calculation and backup rules, `src/db.js` handles storage, and `src/app.js` renders the screens and workflows. The app has no external runtime dependencies, remote fonts, or analytics. Vite and Playwright are development tools only. `public/sw.js` is transformed into a complete offline worker at build time; do not deploy the source directory directly.
