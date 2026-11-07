#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
configuration="${1:-release}"
bundle_id="${BUNDLE_ID:-com.kanta.miniplayer}"
identity="${SIGN_IDENTITY:--}"
project_url="${PROJECT_URL:-https://example.com/Kanta}"
output="$PWD/dist"

if [[ "$(uname -s)" != Darwin ]] || ! xcode-select -p >/dev/null 2>&1 ||
    ! xcrun --find swift >/dev/null 2>&1 || ! xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1; then
    echo "Kanta requires macOS and Apple's Command Line Tools. Run xcode-select --install." >&2
    exit 1
fi
if [[ ! "$bundle_id" =~ ^[A-Za-z0-9][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*){2,}$ ]]; then
    echo "BUNDLE_ID must be a reverse-DNS identifier, such as com.example.kanta." >&2
    exit 1
fi

mkdir -p "$output"
stage="$(mktemp -d "$output/.bundle.XXXXXX")"
trap 'rm -rf "$stage"' EXIT

build_flags=()
if [[ "${UNIVERSAL:-0}" == 1 ]]; then
    build_flags=(--arch arm64 --arch x86_64)
fi
# SWIFT_FLAGS supports local build settings such as a custom compiler cache directory.
read -r -a extra <<< "${SWIFT_FLAGS:-}"
xcrun swift build -c "$configuration" --product Kanta ${build_flags[@]+"${build_flags[@]}"} ${extra[@]+"${extra[@]}"}
bin="$(xcrun swift build -c "$configuration" --show-bin-path ${build_flags[@]+"${build_flags[@]}"} ${extra[@]+"${extra[@]}"})"

app="$stage/Kanta.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
install -m 755 "$bin/Kanta" "$app/Contents/MacOS/Kanta"
install -m 644 Resources/Kanta.icns "$app/Contents/Resources/Kanta.icns"
install -m 644 Bundling/Info.plist "$app/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$bundle_id" "$app/Contents/Info.plist"
plutil -replace KantaProjectURL -string "$project_url" "$app/Contents/Info.plist"
plutil -lint "$app/Contents/Info.plist"

if [[ "$identity" == "-" ]]; then
    codesign --force --sign - --timestamp=none --entitlements Bundling/Kanta.entitlements "$app"
else
    codesign --force --sign "$identity" --options runtime --timestamp --entitlements Bundling/Kanta.entitlements "$app"
fi
codesign --verify --strict "$app"
rm -rf "$output/Kanta.app"
mv "$app" "$output/Kanta.app"
printf 'Built %s\n' "$output/Kanta.app"
