#!/usr/bin/env bash
# Install the pinned XcodeGen release, verifying its SHA-256 before execution.
set -euo pipefail

VERSION="2.46.0"
URL="https://github.com/yonaskolb/XcodeGen/releases/download/${VERSION}/xcodegen.zip"
SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"
DEST=".tools/xcodegen"
ZIP=".tools/xcodegen-${VERSION}.zip"

if [[ -x "${DEST}/xcodegen" ]] && "${DEST}/xcodegen" --version 2>/dev/null | grep -q "${VERSION}"; then
  echo "XcodeGen ${VERSION} is already installed at ${DEST}"
  exit 0
fi

mkdir -p .tools
echo "Downloading XcodeGen ${VERSION}"
curl -fsSL --retry 3 --retry-delay 2 -o "${ZIP}" "${URL}"

ACTUAL_SHA="$(shasum -a 256 "${ZIP}" | awk '{print $1}')"
if [[ "${ACTUAL_SHA}" != "${SHA256}" ]]; then
  echo "::error::XcodeGen checksum mismatch. Expected ${SHA256}, received ${ACTUAL_SHA}." >&2
  exit 1
fi
echo "Checksum verified: ${ACTUAL_SHA}"

rm -rf "${DEST}"
mkdir -p "${DEST}"
# The release archive also contains XcodeGen's setting presets; keep the whole
# directory so project generation behaves like a normal install.
unzip -q -o "${ZIP}" -d "${DEST}"
chmod +x "${DEST}/xcodegen"

INSTALLED="$("${DEST}/xcodegen" --version)"
if [[ "${INSTALLED}" != *"${VERSION}"* ]]; then
  echo "::error::XcodeGen reported '${INSTALLED}', expected ${VERSION}." >&2
  exit 1
fi
echo "XcodeGen installed: ${INSTALLED}"
