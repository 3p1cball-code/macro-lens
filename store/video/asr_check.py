"""Prueft die Sprecheraufnahmen per Whisper (Verstaendlichkeit/Abschneiden)."""
import json, os, sys
from faster_whisper import WhisperModel
lang = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
m = WhisperModel("large-v3-turbo", device="cuda", compute_type="float16")
for ln in json.load(open(os.path.join(here, "vo.json")))["lines"]:
    p = os.path.join(here, "out", "vo", lang, ln["id"] + ".wav")
    segs, _ = m.transcribe(p, language=lang, beam_size=5)
    print(f"{ln['id']:8s} SOLL: {ln[lang]}\n         IST:  {' '.join(s.text.strip() for s in segs)}")
