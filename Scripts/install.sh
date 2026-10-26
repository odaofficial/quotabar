#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -d "dist/Oda Limits.app" ]; then ./Scripts/package.sh; fi
mkdir -p "$HOME/Applications"
ditto "dist/Oda Limits.app" "$HOME/Applications/Oda Limits.app"
printf 'Installed %s\n' "$HOME/Applications/Oda Limits.app"
printf 'Open it with: open "$HOME/Applications/Oda Limits.app"\n'
