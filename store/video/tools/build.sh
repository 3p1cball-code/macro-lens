#!/usr/bin/env bash
# Store-Video komplett bauen: Frames rendern -> Ton mischen -> mp4.
#   tools/build.sh            (de + en)
#   tools/build.sh de
# Sprecher vorher einmalig: tools/tts.sh  (erzeugt out/vo/*, out/vo_*.json, out/words_*.json)
set -euo pipefail
cd "$(dirname "$0")/.."
PY=~/.local/opt/chatterbox/.venv/bin/python
LANGS=("$@"); [ ${#LANGS[@]} -eq 0 ] && LANGS=(de en)
for lang in "${LANGS[@]}"; do
  node render.mjs "$lang"
  $PY mix.py "$lang"
  ffmpeg -y -loglevel error -framerate 30 -i "out/frames_$lang/f%05d.png" -i "out/audio_$lang.wav" \
    -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -profile:v high -r 30 \
    -af "loudnorm=I=-16:TP=-1.5:LRA=11" -c:a aac -b:a 192k -ar 48000 \
    -shortest -movflags +faststart "out/macro-lens-store-$lang.mp4"
  echo "-> out/macro-lens-store-$lang.mp4"
done
