#!/usr/bin/env bash
# Installiert das Godot-Android-Build-Template aus den Export-Templates und
# passt es an die lokal installierte NDK-Version an (kleinere, gestrippte APK).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${SHADEGUNNER_TOOLS:-$HOME/.local/opt/shadegunner-tools}"
TEMPLATES="$TOOLS/export_templates"
VER="$(ls "$TEMPLATES" | head -1)"

if [ ! -f "$TEMPLATES/$VER/android_source.zip" ]; then
	echo "Fehler: $TEMPLATES/$VER/android_source.zip nicht gefunden." >&2
	exit 1
fi

echo ">> entpacke Build-Template $VER …"
mkdir -p "$ROOT/android/build"
unzip -q -o "$TEMPLATES/$VER/android_source.zip" -d "$ROOT/android/build"

# Godot erwartet die Versionsdatei im ELTERN-Verzeichnis des Build-Ordners.
printf '%s' "$VER" > "$ROOT/android/.build_version"
# Godot darf das Template nicht importieren.
touch "$ROOT/android/.gdignore"

# NDK auf die lokal vorhandene Version setzen.
NDK="${NDK_VERSION:-$(ls "$TOOLS/android-sdk/ndk" 2>/dev/null | head -1 || true)}"
if [ -n "${NDK:-}" ]; then
	sed -i -E "s/ndkVersion +: '[^']*'/ndkVersion         : '$NDK'/" "$ROOT/android/build/config.gradle"
	echo ">> NDK auf $NDK gesetzt"
fi

echo "OK: Build-Template $VER installiert."
