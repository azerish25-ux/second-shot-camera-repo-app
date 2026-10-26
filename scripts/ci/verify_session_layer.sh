#!/usr/bin/env bash
#
# Runs the session-layer fault journeys on Linux, before CI reaches macOS.
#
# The SwiftUI application cannot be built off macOS, but the session adapter, the
# storage actor, the serialized media queue and their journey tests use Foundation
# only. This script assembles a throwaway Swift package from those exact sources
# plus the journey tests, so a coordinator defect fails here in seconds instead of
# after a multi-minute simulator run.
#
# It is a development convenience, not a replacement for the simulator workflow:
# it never compiles the app target or its SwiftUI views.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# A stable directory so SwiftPM's build cache is reused between runs; set
# SECOND_SHOT_SESSION_LAYER_DIR to isolate a run.
work_dir="${SECOND_SHOT_SESSION_LAYER_DIR:-${TMPDIR:-/tmp}/second-shot-session-layer}"
mkdir -p "$work_dir"

package="$work_dir/session-layer"
rm -rf "$package/Sources" "$package/Tests"
mkdir -p "$package/Sources" "$package/Tests/SecondShotSessionTests"

cp -R "$repo_root/Sources/SecondShotCore" "$package/Sources/SecondShotCore"
cp -R "$repo_root/Sources/SecondShotApp/Session" "$package/Sources/SecondShotSession"

cat > "$package/Package.swift" <<'SWIFT'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SecondShotSessionLayer",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "SecondShotCore", path: "Sources/SecondShotCore"),
        .target(
            name: "SecondShotSession",
            dependencies: ["SecondShotCore"],
            path: "Sources/SecondShotSession"
        ),
        .testTarget(
            name: "SecondShotSessionTests",
            dependencies: ["SecondShotSession"],
            path: "Tests/SecondShotSessionTests"
        )
    ]
)
SWIFT

# Only the module name in that one import differs from the app target.
sed 's/^@testable import SecondShot$/@testable import SecondShotSession/' \
    "$repo_root/Tests/SecondShotAppTests/SessionCoordinatorJourneyTests.swift" \
    > "$package/Tests/SecondShotSessionTests/SessionCoordinatorJourneyTests.swift"

cd "$package"
swift test
