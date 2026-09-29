#!/bin/sh
# Writes assets/data/build_info.json (shown in the in-game debug menu) with the current
# UTC date/time and a title. Run right before committing:
#   tools/stamp_build.sh "short description" && git add assets/data/build_info.json
cd "$(dirname "$0")/.." || exit 1
TITLE=$(printf '%s' "${1:-}" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '{\n\t"date": "%s",\n\t"title": "%s"\n}\n' "$(date -u '+%Y-%m-%d %H:%M UTC')" "$TITLE" > assets/data/build_info.json
