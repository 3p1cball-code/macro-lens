#!/usr/bin/env bash
# Exportiert eine signierte Release-APK.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${SHADEGUNNER_TOOLS:-$HOME/.local/opt/shadegunner-tools}"

export JAVA_HOME="${JAVA_HOME:-$TOOLS/jdk17}"
export ANDROID_HOME="${ANDROID_HOME:-$TOOLS/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$TOOLS/godotdata}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$TOOLS/godotconfig}"

mkdir -p "$ROOT/build"
"$TOOLS/bin/godot" --headless --path "$ROOT" --export-release "Android" "$ROOT/build/macro-lens.apk"
echo "OK: $ROOT/build/macro-lens.apk"
