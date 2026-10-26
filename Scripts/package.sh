#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
app="dist/Oda Limits.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/OdaLimits "$app/Contents/MacOS/OdaLimits"
cp Scripts/Info.plist "$app/Contents/Info.plist"
ditto Sources/OdaLimits/Resources "$app/Contents/Resources/ProviderMarks"
cp docs/licenses/SIMPLE-ICONS-LICENSE docs/licenses/SVGL-LICENSE "$app/Contents/Resources/"
iconset="$(mktemp -d)/OdaLimits.iconset"
mkdir -p "$iconset"
swift Scripts/make-icon.swift "$iconset/icon_512x512@2x.png"
for n in 16 32 128 256 512; do
    sips -s format png -z "$n" "$n" "$iconset/icon_512x512@2x.png" --out "$iconset/icon_${n}x${n}.png" >/dev/null
    double=$((n * 2))
    if [ "$double" -le 1024 ]; then
        sips -s format png -z "$double" "$double" "$iconset/icon_512x512@2x.png" --out "$iconset/icon_${n}x${n}@2x.png" >/dev/null
    fi
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/OdaLimits.icns"
rm -r "$(dirname "$iconset")"
codesign --force --sign - "$app"
printf 'Packaged %s\n' "$app"
