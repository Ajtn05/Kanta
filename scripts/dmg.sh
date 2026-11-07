#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
stage="$(mktemp -d "$PWD/dist/.dmg.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
ditto dist/Kanta.app "$stage/Kanta.app"
ln -s /Applications "$stage/Applications"
hdiutil create -ov -format UDZO -volname Kanta -srcfolder "$stage" "$PWD/dist/Kanta.dmg"
