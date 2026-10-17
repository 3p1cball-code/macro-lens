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
	rm -rf "$ROOT/store/screenshots/$lang"
	mkdir -p "$ROOT/store/screenshots/$lang"
	shot live     "$lang" "1_vergleich"
	shot live     "$lang" "2_allergene"     "--alerts=milk,nuts,lactose,gluten"
	shot live     "$lang" "3_eigene_seite"  "--layout=macros,density,sugar,fiber,ampel"
	shot layout   "$lang" "4_bausteine"     --empty
	shot alerts   "$lang" "5_allergen_liste" "--empty --alerts=milk,nuts,gluten,lactose"
	shot live     "$lang" "6_kein_lebensmittel" "--nonfood --empty"
	shot generics "$lang" "7_grundnahrung"
done
rm -rf "$USERDATA"
echo "OK: Screenshots in $ROOT/store/screenshots"
