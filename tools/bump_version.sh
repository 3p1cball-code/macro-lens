#!/usr/bin/env bash
# Erhoeht version/code (in beiden Presets) und setzt optional version/name.
# Aufruf:  tools/bump_version.sh [0.3.0]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CFG="$ROOT/export_presets.cfg"

if [ ! -f "$CFG" ]; then
	echo "Fehler: $CFG fehlt (aus export_presets.cfg.example erzeugen)." >&2
	exit 1
fi

CODE="$(grep -E '^version/code=' "$CFG" | head -1 | cut -d= -f2)"
if ! [[ "$CODE" =~ ^[0-9]+$ ]]; then
	echo "Fehler: version/code nicht gefunden." >&2
	exit 1
fi
NEW=$((CODE + 1))

sed -i -E "s/^version\/code=.*/version\/code=$NEW/" "$CFG"

if [ "${1:-}" != "" ]; then
	NAME="$1"
	sed -i -E "s|^version/name=.*|version/name=\"$NAME\"|" "$CFG"
	sed -i -E "s|^config/version=.*|config/version=\"$NAME\"|" "$ROOT/project.godot"
	echo "versionName -> $NAME"
fi

echo "versionCode -> $NEW"
