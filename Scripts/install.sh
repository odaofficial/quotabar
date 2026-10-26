#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -d "dist/QuotaBar.app" ]; then ./Scripts/package.sh; fi
mkdir -p "$HOME/Applications"
new_app="$HOME/Applications/QuotaBar.app"
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Scripts/Info.plist)
pkill -x QuotaBar 2>/dev/null || true
for existing_app in "$HOME/Applications/"*.app; do
    [ -d "$existing_app" ] || continue
    [ "$existing_app" != "$new_app" ] || continue
    existing_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$existing_app/Contents/Info.plist" 2>/dev/null || true)
    [ "$existing_id" = "$bundle_id" ] || continue
    # Recognize an earlier installation by identity, regardless of its folder name.
    existing_executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$existing_app/Contents/Info.plist" 2>/dev/null || true)
    if [ -n "$existing_executable" ]; then pkill -x "$existing_executable" 2>/dev/null || true; fi
    if [ ! -e "$new_app" ]; then
        mv "$existing_app" "$new_app"
    else
        rm -r "$existing_app"
    fi
done
if [ -d "$new_app/Contents" ]; then
    # ditto merges directories, so clear obsolete executable and icon files first.
    rm -r "$new_app/Contents"
fi
ditto "dist/QuotaBar.app" "$new_app"
printf 'Installed %s\n' "$new_app"
printf 'Open it with: open "$HOME/Applications/QuotaBar.app"\n'
