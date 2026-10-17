#!/usr/bin/env bash
# Sprecherstimme erzeugen (DE mit Thorsten-Referenz CC0, EN mit Chatterbox-Standardstimme).
# Voraussetzung: venv unter ~/.local/opt/chatterbox (chatterbox-tts, faster-whisper,
# setuptools<81 fuer den Perth-Watermarker), Referenz unter ~/.local/opt/chatterbox/ref.
set -euo pipefail
cd "$(dirname "$0")/.."
PY=~/.local/opt/chatterbox/.venv/bin/python
LIBS=$($PY -c "import os,nvidia.cublas.lib as a,nvidia.cudnn.lib as b;print(os.path.dirname(a.__file__)+':'+os.path.dirname(b.__file__))")
export LD_LIBRARY_PATH="$LIBS${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
REF=~/.local/opt/chatterbox/ref/thorsten_ref1.wav
LANGS=("$@"); [ ${#LANGS[@]} -eq 0 ] && LANGS=(de en)
for lang in "${LANGS[@]}"; do
  if [ "$lang" = de ]; then
    $PY tts.py de --ref "$REF"
  else
    $PY tts.py "$lang"
  fi
done
$PY align.py "${LANGS[@]}"
