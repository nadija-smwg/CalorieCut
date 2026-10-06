#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "Full iOS validation requires Xcode 16 or newer on macOS."
    exit 1
fi
xcodebuild -version
swift test
xcodebuild -project CalorieCut.xcodeproj -scheme CalorieCut -configuration Debug \
    -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
simulator_id="${SIMULATOR_UDID:-}"
if [ -z "$simulator_id" ]; then
    simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; devices=json.load(sys.stdin)["devices"]; matches=[d["udid"] for runtime,items in sorted(devices.items(), reverse=True) if "iOS" in runtime for d in items if "iPhone" in d["name"] and d.get("isAvailable",False)]; print(matches[0] if matches else "")')"
fi
if [ -z "$simulator_id" ]; then
    echo "Install an iOS 17+ iPhone simulator in Xcode Settings > Components, then rerun."
    exit 1
fi
mkdir -p TestResults
result_path="TestResults/CalorieCut-$(date +%Y%m%d-%H%M%S).xcresult"
xcodebuild -project CalorieCut.xcodeproj -scheme CalorieCut -configuration Debug \
    -destination "platform=iOS Simulator,id=$simulator_id" CODE_SIGNING_ALLOWED=NO \
    -resultBundlePath "$result_path" test
echo "Build and tests passed. Complete the device checks in QA.md before release."
