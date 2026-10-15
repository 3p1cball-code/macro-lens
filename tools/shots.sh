#!/usr/bin/env bash
# Rendert Screenshots aller Screens (Demo-Daten) nach screenshots/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${SHADEGUNNER_TOOLS:-$HOME/.local/opt/shadegunner-tools}"
DRIVER="${DISPLAY_DRIVER:-x11}"
RES="${SHOT_RES:-480x854}"

export XDG_DATA_HOME="${XDG_DATA_HOME:-$TOOLS/godotdata}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$TOOLS/godotconfig}"

mkdir -p "$ROOT/screenshots"
for s in live generics history search about settings; do
	"$TOOLS/bin/godot" --display-driver "$DRIVER" --resolution "$RES" --path "$ROOT" \
		-- --shot="$ROOT/screenshots/$s.png" --screen="$s" >/dev/null 2>&1 || true
	echo "  $s.png"
done
echo "OK: Screenshots in $ROOT/screenshots"
