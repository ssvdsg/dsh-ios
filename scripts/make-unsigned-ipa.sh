#!/usr/bin/env bash
# Package an unsigned .xcarchive as an unsigned IPA for on-device signing.
#
# Usage: scripts/make-unsigned-ipa.sh [path/to/DSH.xcarchive] [output.ipa]
#
# The archive must already exist (see .github/workflows/build-ipa.yml or run
# xcodebuild archive with CODE_SIGNING_ALLOWED=NO). No signing identity or
# provisioning profile is applied here; sign the resulting IPA with your own
# tool before installing it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE="${1:-$ROOT/build/DSH.xcarchive}"
OUT="${2:-$ROOT/build/DSH-unsigned.ipa}"
APP="$ARCHIVE/Products/Applications/DSH.app"
WORK="$ROOT/build/ipa"

[ -d "$APP" ] || {
    echo "error: $APP not found" >&2
    echo "hint: run xcodebuild archive with CODE_SIGNING_ALLOWED=NO first" >&2
    exit 1
}

OUT_DIR="$(dirname "$OUT")"
mkdir -p "$OUT_DIR"
OUT="$(cd "$OUT_DIR" && pwd)/$(basename "$OUT")"

rm -rf "$WORK"
mkdir -p "$WORK/Payload"
ditto "$APP" "$WORK/Payload/DSH.app"

[ -x "$WORK/Payload/DSH.app/DSH" ] || {
    echo "error: the archive has no DSH executable at Payload/DSH.app/DSH" >&2
    exit 1
}

# An unsigned archive should not carry these, but remove them defensively so a
# stale signature cannot make the sideload signer reject the bundle.
rm -rf "$WORK/Payload/DSH.app/_CodeSignature" \
       "$WORK/Payload/DSH.app/embedded.mobileprovision"
find "$WORK/Payload" -name '._*' -delete
find "$WORK/Payload" -name '.DS_Store' -delete

rm -f "$OUT" "$OUT.sha256"
# zip -y keeps framework/helper symlinks as symlinks, which iOS expects.
( cd "$WORK" && zip -qry "$OUT" Payload )

unzip -l "$OUT" | head -5
shasum -a 256 "$OUT" | tee "$OUT.sha256"
echo "unsigned IPA: $OUT"
