# Install CalorieCut using a Windows computer

You can do this without owning a Mac and without a paid Apple Developer subscription. GitHub Actions supplies a cloud Mac to compile the app. AltStore Classic and AltServer on your Windows computer then sign it using your Apple ID and install it on your iPhone.

**Current status:** the cloud workflow is included but has not been run from this workspace. The project has passed the documented Linux checks. A usable device IPA is created only after the cloud's simulator build/tests and iPhone build succeed. It is unsigned until AltStore signs it. No prebuilt or fake IPA is included in this download.

You need a Windows computer, an iPhone running iOS 17+, a USB cable, a GitHub account, and an Apple ID. Internet is needed for building, signing, and periodic signature refresh; the installed CalorieCut app and its data work offline.

## 1. Put the project on GitHub

Use [GitHub Desktop](https://desktop.github.com/download/) on Windows if you are new to Git:

1. Extract `CalorieCut-Windows.zip` with Windows **Extract All**. Open the extracted `CalorieCut` folder.
2. Install GitHub Desktop, open it, and sign in to your GitHub account.
3. Choose **File → New repository**. Name it `CalorieCut`, select a local path, and click **Create repository**.
4. In GitHub Desktop, choose **Repository → Show in Explorer**. This is the new repository folder.
5. Copy the **contents** of the extracted project folder into that repository folder. The repository root must contain `.github`, `CalorieCut.xcodeproj`, `Scripts`, `Package.swift`, and the `CalorieCut` source folder. Do not add an extra enclosing `CalorieCut` folder. Preserve the `.github` folder; it contains the cloud workflow.
6. In GitHub Desktop, enter a summary such as `Add CalorieCut app`, click **Commit to main**, then **Publish repository**.

Choose visibility deliberately: a public repository exposes the source but standard GitHub macOS Actions runners are free; private repositories use your account's included Actions allowance and can incur charges when that allowance is exhausted. No personal diary, signing certificate, or Apple ID credentials need to be uploaded.

Official runner availability and billing: [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

## 2. Run the cloud Mac build

1. Open your repository on GitHub in a browser.
2. Click **Actions → Build CalorieCut for iPhone**. The first push normally starts a run automatically. Otherwise choose **Run workflow → Run workflow** on your default branch.
3. Wait for the run to finish. It checks project files, runs the same calculation tests plus the iOS integration/UI tests, and compiles an ARM64 iPhone app in Release mode.
4. When the run is green, open its summary and download the **CalorieCut-unsigned-iPhone** artifact. GitHub wraps it in a ZIP; extract it to obtain `CalorieCut-unsigned.ipa`.
5. If the run fails, open the red step or download **CalorieCut-build-logs**, and send the error output back for a fix. The workflow does not continue after a failed test or build.

Artifacts are retained for seven days; save your build if you want to keep it. You can rerun the workflow to produce a fresh build. The workflow requires no secrets and never asks for your Apple ID. GitHub is a build service here, not an app backend.

## 3. Set up AltStore Classic on Windows

Follow the current [official AltStore Windows installation guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) for downloads and any Windows-version-specific changes. Use **AltStore Classic**, rather than AltStore PAL.

The official guide currently calls for Apple's direct-download iTunes/iCloud installers, AltServer for Windows, connecting/trusting your unlocked phone, enabling Wi-Fi sync in iTunes, and installing AltStore from AltServer's taskbar menu. Enter your Apple ID in the official local AltServer/AltStore setup; the cloud workflow does not need it.

On your iPhone, trust the developer identity under **Settings → General → VPN & Device Management**, then enable **Settings → Privacy & Security → Developer Mode** and follow the restart prompts. Keep AltServer running on Windows while signing/installing. The computer and phone need an appropriate connection (USB or configured Wi-Fi sync).

## 4. Install the cloud-built IPA

1. Get `CalorieCut-unsigned.ipa` into the iPhone's Files app. You can open the successful GitHub run in Safari on your iPhone, sign in, download the same artifact, and tap its ZIP in Files to extract it. This avoids transferring the file from Windows. Alternatively transfer the already downloaded IPA using your preferred method.
2. Open **AltStore → My Apps → +**, select the IPA in Files, and let AltStore sign/install it with your Apple ID while AltServer is reachable.
3. Open **CalorieCut** from your iPhone Home Screen. Complete onboarding and edit the example values to suit you.
4. Log food, water, and measurements, then close/reopen the app to check persistence. Continue with `QA.md` for the full device checks.

An unsigned IPA cannot install by tapping it directly in Files; AltStore supplies the required signing/provisioning. If AltStore reports an error, record the error text and use its [troubleshooting guide](https://faq.altstore.io/altstore-classic/troubleshooting-guide).

## 5. Keep it usable

With free Apple ID provisioning, AltStore's sideloaded apps expire after seven days unless refreshed. Use **AltStore → My Apps → Refresh All** while AltServer is reachable, or allow AltStore's supported background refresh. Apple's free-account limit is three active sideloaded apps; AltStore itself uses one slot.

Refreshing an existing installation normally preserves its local diary. Export a JSON backup before reinstalling, deleting, deactivating, or changing signing accounts. CalorieCut excludes its database from automatic device backups, so use its built-in backup feature regularly.

Official refresh/expiration details: [AltStore Getting Started](https://faq.altstore.io/altstore-classic/your-altstore).

A paid developer account/TestFlight is an alternative if you want a different distribution route; it is not required for this Windows/AltStore approach.
