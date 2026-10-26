#!/usr/bin/env bash
# Install the pinned XcodeGen release, verifying its SHA-256 before execution.
# The release archive nests the tool as xcodegen/bin/xcodegen plus its setting
# presets under xcodegen/share, so the whole tree is installed together.
set -euo pipefail

VERSION="2.46.0"
URL="https://github.com/yonaskolb/XcodeGen/releases/download/${VERSION}/xcodegen.zip"
SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"
DEST=".tools/xcodegen"
BIN="${DEST}/bin/xcodegen"
ZIP=".tools/xcodegen-${VERSION}.zip"

if [[ -x "${BIN}" ]] && "${BIN}" --version 2>/dev/null | grep -q "${VERSION}"; then
  echo "XcodeGen ${VERSION} is already installed at ${BIN}"
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
# Unzipping into .tools creates .tools/xcodegen/{bin,share,LICENSE}, matching the
# layout XcodeGen expects for its bundled setting presets.
unzip -q -o "${ZIP}" -d .tools
if [[ ! -f "${BIN}" ]]; then
  echo "::error::XcodeGen archive did not contain bin/xcodegen at ${BIN}." >&2
  find .tools -maxdepth 3 -print
  exit 1
fi
chmod +x "${BIN}"

INSTALLED="$("${BIN}" --version)"
if [[ "${INSTALLED}" != *"${VERSION}"* ]]; then
  echo "::error::XcodeGen reported '${INSTALLED}', expected ${VERSION}." >&2
  exit 1
fi
echo "XcodeGen installed: ${INSTALLED}"
