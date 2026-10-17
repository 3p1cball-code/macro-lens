#!/usr/bin/env bash
# Rendert Screenshots aller Screens (Demo-Daten) nach screenshots/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${SHADEGUNNER_TOOLS:-$HOME/.local/opt/shadegunner-tools}"
DRIVER="${DISPLAY_DRIVER:-x11}"
RES="${SHOT_RES:-480x854}"

export XDG_DATA_HOME="${XDG_DATA_HOME:-$TOOLS/godotdata}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$TOOLS/godotconfig}"

USERDATA="$TOOLS/godotdata/godot/app_userdata/Macro Lens"
mkdir -p "$ROOT/screenshots"

shot() { # name screen [extra]
	local name="$1" screen="$2" extra="${3:-}"
	rm -rf "$USERDATA"
	"$TOOLS/bin/godot" --display-driver "$DRIVER" --resolution "$RES" --path "$ROOT" \
		-- --shot="$ROOT/screenshots/$name.png" --screen="$screen" $extra >/dev/null 2>&1 || true
	echo "  $name.png"
}

for s in live generics history search about settings; do
	shot "$s" "$s"
done
shot live_single live --single
shot live_two live --two
shot live_empty live --empty
shot live_nodata live --nodata
shot live_nonfood live --nonfood --empty
shot live_custom live "--layout=macros,density,sugar,fiber,ampel"
shot live_quit live --show-quit
shot layout layout --empty
shot live_alerts live "--alerts=milk,nuts,lactose,gluten"
shot alerts alerts --empty "--alerts=milk,nuts,lactose"

rm -rf "$USERDATA"
echo "OK: Screenshots in $ROOT/screenshots"
