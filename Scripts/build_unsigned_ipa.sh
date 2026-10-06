#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
if [ "$(uname -s)" != "Darwin" ] || ! command -v xcodebuild >/dev/null 2>&1; then
    echo "This script requires a Mac with Xcode. Windows users run the included GitHub Actions workflow."
    exit 1
fi
build_root="$project_root/.device-build"
output_root="$project_root/Output"
staging_root="$(mktemp -d "${TMPDIR:-/tmp}/caloriecut-package.XXXXXX")"
trap 'rm -rf "$staging_root"' EXIT
mkdir -p "$output_root"
xcodebuild -project CalorieCut.xcodeproj -scheme CalorieCut -configuration Release \
    -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath "$build_root" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' build
app_path="$build_root/Build/Products/Release-iphoneos/CalorieCut.app"
if [ ! -f "$app_path/Info.plist" ] || [ ! -f "$app_path/CalorieCut" ]; then
    echo "The compiled iPhone app was not found. No IPA will be produced."
    exit 1
fi
python3 - "$app_path" <<'PY'
import plistlib
from pathlib import Path
import sys
app = Path(sys.argv[1])
with (app / 'Info.plist').open('rb') as file:
    info = plistlib.load(file)
if info.get('DTPlatformName') != 'iphoneos':
    raise SystemExit('Refusing to package a simulator or non-iPhone app.')
if info.get('CFBundleExecutable') != 'CalorieCut' or (app / 'CalorieCut').stat().st_size == 0:
    raise SystemExit('Missing or empty compiled executable.')
print('Validated compiled iPhone app:', info['CFBundleIdentifier'])
PY
xcrun lipo -verify_arch arm64 "$app_path/CalorieCut"
mkdir -p "$staging_root/Payload"
ditto "$app_path" "$staging_root/Payload/CalorieCut.app"
ipa_path="$output_root/CalorieCut-unsigned.ipa"
# Remove an earlier output so zip cannot retain stale files from an older app.
rm -f "$ipa_path"
(
    cd "$staging_root"
    /usr/bin/zip -q -r "$ipa_path" Payload
)
python3 - "$ipa_path" <<'PY'
import sys
import zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    if archive.testzip() is not None:
        raise SystemExit('IPA archive integrity check failed.')
    required = {'Payload/CalorieCut.app/Info.plist', 'Payload/CalorieCut.app/CalorieCut'}
    if not required.issubset(archive.namelist()):
        raise SystemExit('IPA is missing its executable or Info.plist.')
print('Created a real compiled, UNSIGNED device IPA. Sign it locally before installing.')
PY
