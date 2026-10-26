#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Map both debug and source-location paths before stripping linker debug symbols.
root="$(pwd -P)"
swift build -c release -Xswiftc -DQUOTABAR_PACKAGED -Xswiftc -debug-prefix-map -Xswiftc "$root=/source/QuotaBar" \
    -Xswiftc -file-prefix-map -Xswiftc "$root=/source/QuotaBar"
# Stage a fresh bundle so previous package contents cannot enter a new release.
staging="$(mktemp -d)"
trap 'rm -r "$staging"' EXIT
app="$staging/QuotaBar.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/QuotaBar "$app/Contents/MacOS/QuotaBar"
cp Scripts/Info.plist "$app/Contents/Info.plist"
ditto Sources/QuotaBar/Resources "$app/Contents/Resources/ProviderMarks"
cp docs/licenses/SIMPLE-ICONS-LICENSE docs/licenses/SVGL-LICENSE "$app/Contents/Resources/"
iconset="$staging/QuotaBar.iconset"
mkdir -p "$iconset"
swift Scripts/make-icon.swift "$iconset/icon_512x512@2x.png"
for n in 16 32 128 256 512; do
    sips -s format png -z "$n" "$n" "$iconset/icon_512x512@2x.png" --out "$iconset/icon_${n}x${n}.png" >/dev/null
    double=$((n * 2))
    if [ "$double" -le 1024 ]; then
        sips -s format png -z "$double" "$double" "$iconset/icon_512x512@2x.png" --out "$iconset/icon_${n}x${n}@2x.png" >/dev/null
    fi
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/QuotaBar.icns"
strip -S "$app/Contents/MacOS/QuotaBar"
/usr/bin/xattr -cr "$app"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
archive="QuotaBar-$version-macos-$(uname -m).zip"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr -c -k --keepParent "$app" "$staging/$archive"
python3 Scripts/verify-release.py "$staging/$archive"
mkdir -p dist
# ditto updates an existing installed staging bundle; release ZIP uses the fresh bundle above.
COPYFILE_DISABLE=1 ditto --norsrc --noextattr "$app" dist/QuotaBar.app
cp "$staging/$archive" "dist/$archive"
(cd dist && shasum -a 256 "$archive" > SHA256SUMS)
printf 'Packaged dist/%s\n' "$archive"
