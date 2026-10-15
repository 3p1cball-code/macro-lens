#!/usr/bin/env bash
# Rendert die Google-Play-Screenshots (1080x1920) auf Deutsch und Englisch.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${SHADEGUNNER_TOOLS:-$HOME/.local/opt/shadegunner-tools}"
USERDATA="$TOOLS/godotdata/godot/app_userdata/Macro Lens"

export XDG_DATA_HOME="${XDG_DATA_HOME:-$TOOLS/godotdata}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$TOOLS/godotconfig}"

shot() { # screen lang outname [extra]
	local screen="$1" lang="$2" name="$3" extra="${4:-}"
	rm -rf "$USERDATA"
	"$TOOLS/bin/godot" --display-driver "${DISPLAY_DRIVER:-x11}" --resolution 400x700 --path "$ROOT" \
		-- --shot="$ROOT/store/screenshots/$lang/$name.png" --screen="$screen" \
		--shot-size=1080x1920 --lang="$lang" $extra >/dev/null 2>&1 || true
	echo "  $lang/$name.png"
}

for lang in de en; do
	mkdir -p "$ROOT/store/screenshots/$lang"
	shot live     "$lang" "1_dauerscan"
	shot live     "$lang" "2_vergleich"  --two
	shot live     "$lang" "3_produkt"    --single
	shot generics "$lang" "4_grundnahrung"
done
rm -rf "$USERDATA"
echo "OK: Screenshots in $ROOT/store/screenshots"
