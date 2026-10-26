#!/usr/bin/env bash
# Concurrency diagnostics: rerun the unit suites under Thread Sanitizer.
#
# Phase 03 introduced real concurrent work (a main-actor coordinator, a storage
# actor, a serialized media queue and injected providers), so the phase's own
# verification asks for the race diagnostics the toolchain supports. The UI suites
# are deliberately excluded: they are slow under instrumentation, and the code
# under test here is the unit-level session layer.
#
# A report from this run is evidence, not proof of device behaviour: it says
# nothing about ARKit, AVFoundation or physical interruption delivery.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

ARTIFACTS="artifacts/ios"
mkdir -p "${ARTIFACTS}"

if ! command -v xcrun >/dev/null 2>&1 || ! command -v xcodebuild >/dev/null 2>&1; then
  echo "::error::xcrun/xcodebuild are unavailable; Thread Sanitizer needs a macOS runner with Xcode." >&2
  exit 1
fi

if [[ ! -d "SecondShot.xcodeproj" ]]; then
  echo "::error::SecondShot.xcodeproj is missing. Run XcodeGen before this script." >&2
  exit 1
fi

if [[ -f "${ARTIFACTS}/simulator.json" ]]; then
  UDID="$(python3 -B -c 'import json,sys; print(json.load(open(sys.argv[1]))["udid"])' "${ARTIFACTS}/simulator.json")"
else
  xcrun simctl list --json > "${ARTIFACTS}/devices.json"
  python3 -B scripts/ci/select_simulator.py \
    --inventory "${ARTIFACTS}/devices.json" \
    --output "${ARTIFACTS}/simulator.json"
  UDID="$(python3 -B -c 'import json,sys; print(json.load(open(sys.argv[1]))["udid"])' "${ARTIFACTS}/simulator.json")"
fi

RESULT="${ARTIFACTS}/ThreadSanitizer.xcresult"
if [[ -e "${RESULT}" ]]; then
  mv "${RESULT}" "${ARTIFACTS}/ThreadSanitizer-$(date -u +%Y%m%dT%H%M%SZ).xcresult"
fi

echo "Running the unit suites under Thread Sanitizer on ${UDID}"
set +e
xcodebuild test \
  -project SecondShot.xcodeproj \
  -scheme SecondShot \
  -destination "platform=iOS Simulator,id=${UDID}" \
  -derivedDataPath "${ARTIFACTS}/DerivedData" \
  -resultBundlePath "${RESULT}" \
  -only-testing:SecondShotCoreTests \
  -only-testing:SecondShotAppTests \
  -enableThreadSanitizer YES \
  -test-timeouts-enabled YES \
  -maximum-test-execution-time-allowance 600 \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  2>&1 | tee "${ARTIFACTS}/thread-sanitizer.log"
STATUS=${PIPESTATUS[0]}
set -e

echo "${STATUS}" > "${ARTIFACTS}/thread-sanitizer.status"
if [[ "${STATUS}" -ne 0 ]]; then
  echo "::error::Thread Sanitizer reported a problem (status ${STATUS}). Inspect artifacts/ios/thread-sanitizer.log." >&2
  grep -E "WARNING: ThreadSanitizer|SUMMARY: ThreadSanitizer" "${ARTIFACTS}/thread-sanitizer.log" | head -20 || true
fi
exit "${STATUS}"
