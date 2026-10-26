#!/usr/bin/env bash
# Build the app and run unit + UI tests on a deterministically selected simulator.
# Preserves xcodebuild's exit status through the log pipeline.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

ARTIFACTS="artifacts/ios"
mkdir -p "${ARTIFACTS}"

if ! command -v xcrun >/dev/null 2>&1 || ! command -v xcodebuild >/dev/null 2>&1; then
  echo "::error::xcrun/xcodebuild are unavailable. iOS Simulator tests require a macOS runner with Xcode." >&2
  exit 1
fi

if [[ ! -d "SecondShot.xcodeproj" ]]; then
  echo "::error::SecondShot.xcodeproj is missing. Run XcodeGen before this script." >&2
  exit 1
fi

echo "Collecting simulator inventory"
xcrun simctl list --json > "${ARTIFACTS}/devices.json"
xcrun simctl list runtimes --json > "${ARTIFACTS}/runtimes.json"

python3 -B scripts/ci/select_simulator.py \
  --inventory "${ARTIFACTS}/devices.json" \
  --output "${ARTIFACTS}/simulator.json"

UDID="$(python3 -B -c 'import json,sys; print(json.load(open(sys.argv[1]))["udid"])' "${ARTIFACTS}/simulator.json")"
RUNTIME="$(python3 -B -c 'import json,sys; print(json.load(open(sys.argv[1]))["runtime"])' "${ARTIFACTS}/simulator.json")"
DEVICE_NAME="$(python3 -B -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' "${ARTIFACTS}/simulator.json")"
echo "Selected ${DEVICE_NAME} (${UDID}) on ${RUNTIME}"

# Booting first gives readable diagnostics when the runtime is broken.
set +e
xcrun simctl boot "${UDID}" 2>&1 | tee -a "${ARTIFACTS}/boot.log"
BOOT_STATUS=${PIPESTATUS[0]}
set -e
if [[ "${BOOT_STATUS}" -ne 0 ]]; then
  echo "simctl boot returned ${BOOT_STATUS}; checking whether the device nevertheless starts." \
    | tee -a "${ARTIFACTS}/boot.log"
fi

set +e
xcrun simctl bootstatus "${UDID}" -b 2>&1 | tee -a "${ARTIFACTS}/boot.log"
BOOTSTATUS_STATUS=${PIPESTATUS[0]}
set -e
if [[ "${BOOTSTATUS_STATUS}" -ne 0 ]]; then
  echo "::error::Simulator failed to become ready; see artifacts/ios/boot.log" >&2
  exit "${BOOTSTATUS_STATUS}"
fi

RESULT="${ARTIFACTS}/SecondShot.xcresult"
if [[ -e "${RESULT}" ]]; then
  ARCHIVE="${ARTIFACTS}/SecondShot-$(date -u +%Y%m%dT%H%M%SZ).xcresult"
  echo "Archiving an existing result bundle to ${ARCHIVE}"
  mv "${RESULT}" "${ARCHIVE}"
fi

echo "Running xcodebuild test"
set +e
xcodebuild test \
  -project SecondShot.xcodeproj \
  -scheme SecondShot \
  -destination "platform=iOS Simulator,id=${UDID}" \
  -derivedDataPath "${ARTIFACTS}/DerivedData" \
  -resultBundlePath "${RESULT}" \
  -test-timeouts-enabled YES \
  -maximum-test-execution-time-allowance 600 \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  2>&1 | tee "${ARTIFACTS}/xcodebuild.log"
XCODEBUILD_STATUS=${PIPESTATUS[0]}
set -e

echo "${XCODEBUILD_STATUS}" > "${ARTIFACTS}/xcodebuild.status"
if [[ "${XCODEBUILD_STATUS}" -ne 0 ]]; then
  echo "::error::xcodebuild test failed with status ${XCODEBUILD_STATUS}. Inspect artifacts/ios/xcodebuild.log." >&2
fi
exit "${XCODEBUILD_STATUS}"
