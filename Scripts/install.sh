#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -d "dist/QuotaBar.app" ]; then ./Scripts/package.sh; fi
mkdir -p "$HOME/Applications"
old_app="$HOME/Applications/Oda Limits.app"
new_app="$HOME/Applications/QuotaBar.app"
pkill -x OdaLimits 2>/dev/null || true
pkill -x QuotaBar 2>/dev/null || true
if [ -d "$old_app" ]; then
    # Preserve the bundle's location while changing its visible app name.
    if [ ! -e "$new_app" ]; then
        mv "$old_app" "$new_app"
    else
        rm -r "$old_app"
    fi
fi
if [ -d "$new_app/Contents" ]; then
    # ditto merges directories, so clear obsolete executable and icon files first.
    rm -r "$new_app/Contents"
fi
ditto "dist/QuotaBar.app" "$new_app"
printf 'Installed %s\n' "$new_app"
printf 'Open it with: open "$HOME/Applications/QuotaBar.app"\n'
