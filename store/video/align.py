"""Wort-Zeitstempel der Sprecheraufnahmen (Whisper) -> out/words_<lang>.json.

index.html nutzt sie, um Hervorhebungen/Gags genau auf ein Wort zu legen
(z. B. die Ameise auf "Ameise"). Aufruf ueber tools/tts.sh oder direkt.
"""
import json
import os
import sys

from faster_whisper import WhisperModel

HERE = os.path.dirname(os.path.abspath(__file__))


def main() -> None:
    m = WhisperModel("large-v3-turbo", device="cuda", compute_type="float16")
    for lang in sys.argv[1:] or ["de", "en"]:
        out = {}
        for ln in json.load(open(os.path.join(HERE, "vo.json"), encoding="utf-8"))["lines"]:
            p = os.path.join(HERE, "out", "vo", lang, ln["id"] + ".wav")
            segs, _ = m.transcribe(p, language=lang, beam_size=5, word_timestamps=True)
            words = []
            for s in segs:
                for w in s.words:
                    words.append([w.word.strip(), round(w.start, 3), round(w.end, 3)])
            out[ln["id"]] = words
        json.dump(out, open(os.path.join(HERE, "out", f"words_{lang}.json"), "w", encoding="utf-8"),
                  ensure_ascii=False, indent=0)
        print(lang, {k: len(v) for k, v in out.items()})


if __name__ == "__main__":
    main()
