#!/usr/bin/env bash
# Builds the player download: dist/WardrobeUIImprovements-<version>.zip, laid out like the game folder.
# The version comes from WardrobeTabsConfig.Version(); release/README.md becomes the README
# players get. Runs the minimal compile check first and refuses to package a failing build.
# Usage: tools/build-release.sh
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="$PROJECT/mod/r6/scripts/WardrobeTabs"
VERSION="$(sed -n 's/.*func Version() -> String = "\([^"]*\)".*/\1/p' "$SCRIPTS/WardrobeTabs.reds")"
[ -n "$VERSION" ] || { echo "No Version() in WardrobeTabs.reds"; exit 1; }

"$PROJECT/tools/compile-check.sh" --minimal

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/archive/pc/mod" "$STAGE/r6/scripts/WardrobeTabs"
cp "$PROJECT/mod/archive/pc/mod/WardrobeTabs.archive" "$STAGE/archive/pc/mod/"
cp "$SCRIPTS"/*.reds "$STAGE/r6/scripts/WardrobeTabs/"
cp "$PROJECT/release/README.md" "$STAGE/r6/scripts/WardrobeTabs/README.md"
cp "$PROJECT/release/THIRD_PARTY_NOTICES.txt" "$STAGE/r6/scripts/WardrobeTabs/"

mkdir -p "$PROJECT/dist"
OUT="$PROJECT/dist/WardrobeUIImprovements-$VERSION.zip"
rm -f "$OUT"
(cd "$STAGE" && python3 -I -c '
import os, sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk("."):
        for name in sorted(files):
            path = os.path.join(root, name)
            z.write(path, os.path.relpath(path, "."))
' "$OUT")
echo "Built $OUT"
python3 -I -c 'import sys, zipfile; [print("  " + n) for n in zipfile.ZipFile(sys.argv[1]).namelist()]' "$OUT"
