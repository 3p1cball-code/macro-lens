#!/usr/bin/env bash
# Baut das Barcode-Plugin (Android-Plugin v2) als AAR.
# Voraussetzung: Build-Template installiert (tools/setup_build_template.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${SHADEGUNNER_TOOLS:-$HOME/.local/opt/shadegunner-tools}"

export JAVA_HOME="${JAVA_HOME:-$TOOLS/jdk17}"
export ANDROID_HOME="${ANDROID_HOME:-$TOOLS/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

PLUGIN="$ROOT/plugins/macrolens-barcode"
cd "$PLUGIN"
if [ ! -f local.properties ]; then
	echo "sdk.dir=$ANDROID_HOME" > local.properties
fi

"$ROOT/android/build/gradlew" --no-daemon --console=plain assembleRelease

AAR="$PLUGIN/build/outputs/aar/macrolens-barcode-release.aar"
cp "$AAR" "$ROOT/addons/macrolens/macrolens-barcode.aar"
echo "OK: addons/macrolens/macrolens-barcode.aar aktualisiert."
