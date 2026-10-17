"""Sprecherstimme fuer das Store-Video (Chatterbox Multilingual, lokal).

Aufruf:  ~/.local/opt/chatterbox/.venv/bin/python tts.py [de|en] [--ref voice.wav] [--only id]
Ausgabe: out/vo/<lang>/<id>.wav  +  out/vo_<lang>.json (Dauern in s, fuer index.html)

Reproduzierbar: fester Seed je Zeile/Kandidat, Parameter unten fest eingetragen.
Best-of-N: jede Zeile wird bis zu N-mal erzeugt, per Whisper zurueckgelesen und
die textgetreueste Fassung behalten (Chatterbox verschluckt sonst gelegentlich
Woerter oder haengt ein "Aehm" an).
DE nutzt eine Referenzstimme (Thorsten-Voice, CC0), EN die Standardstimme.
"""
import argparse
import difflib
import json
import re
import os
import random

import numpy as np
import torch
import torchaudio as ta

HERE = os.path.dirname(os.path.abspath(__file__))

# Trocken-lakonisch: wenig Uebertreibung, etwas mehr Bindung an den Text.
EXAGGERATION = 0.42
CFG_WEIGHT = 0.4
TEMPERATURE = 0.7
SEED = 1234


def seed_all(s: int) -> None:
    random.seed(s)
    np.random.seed(s)
    torch.manual_seed(s)
    torch.cuda.manual_seed_all(s)


def trim(wav: torch.Tensor, sr: int, thresh_db: float = -45.0, pad_s: float = 0.06) -> torch.Tensor:
    """Stille vorn/hinten abschneiden (Timing im Video plant selbst)."""
    x = wav[0].numpy()
    win = int(sr * 0.01)
    n = len(x) // win
    if n == 0:
        return wav
    rms = np.sqrt(np.mean(x[: n * win].reshape(n, win) ** 2, axis=1) + 1e-12)
    db = 20 * np.log10(rms)
    idx = np.where(db > thresh_db)[0]
    if len(idx) == 0:
        return wav
    a = max(0, idx[0] * win - int(pad_s * sr))
    b = min(len(x), (idx[-1] + 1) * win + int(pad_s * sr))
    return wav[:, a:b]


NUM = {"zweihundert": "200", "hundert": "100", "two hundred": "200", "a hundred": "100",
       "hundred": "100", "vier": "4", "four": "4"}


def norm(s: str) -> list:
    s = s.lower()
    for k, v in NUM.items():
        s = s.replace(k, v)
    s = re.sub(r"[^a-z0-9äöüß ]+", " ", s.replace("-", " "))
    s = s.replace("macrolens", "macro lens").replace("makrolens", "macro lens").replace("makro lens", "macro lens")
    s = s.replace("mäkro", "macro").replace("äpp", "app").replace("träcking", "tracking").replace("scännt", "scannt")
    return s.split()


def similarity(want: str, heard: str) -> float:
    return difflib.SequenceMatcher(None, norm(want), norm(heard)).ratio()


def choppy(segs) -> float:
    """Strafe fuer Stocken: Pausen mitten im Satz (nicht nach . ? !) > 0,25 s."""
    words = [w for s in segs for w in s.words]
    pen = 0.0
    for a, b in zip(words, words[1:]):
        gap = b.start - a.end
        limit = 0.6 if a.word.strip()[-1:] in ".?!:" else 0.25
        pen += max(0.0, gap - limit) * 0.4
    return pen


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("lang", choices=["de", "en"])
    ap.add_argument("--ref", default="", help="Referenzstimme (wav), sonst Standardstimme")
    ap.add_argument("--only", default="", help="nur diese id neu erzeugen")
    ap.add_argument("--seed", type=int, default=SEED)
    ap.add_argument("--exag", type=float, default=EXAGGERATION)
    ap.add_argument("--n", type=int, default=4, help="Kandidaten je Zeile")
    args = ap.parse_args()

    from chatterbox.mtl_tts import ChatterboxMultilingualTTS

    model = ChatterboxMultilingualTTS.from_pretrained(device="cuda")
    lines = json.load(open(os.path.join(HERE, "vo.json"), encoding="utf-8"))["lines"]
    outdir = os.path.join(HERE, "out", "vo", args.lang)
    os.makedirs(outdir, exist_ok=True)
    meta_path = os.path.join(HERE, "out", f"vo_{args.lang}.json")
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}

    # Best-of-N: jede Zeile N-mal mit festen Seeds erzeugen, per Whisper
    # zuruecklesen und die Fassung nehmen, die dem Soll-Text am naechsten ist
    # (faengt Verschlucker und angehaengtes "Aehm"/Atemgeraeusch ab).
    from faster_whisper import WhisperModel
    asr = WhisperModel("large-v3-turbo", device="cuda", compute_type="float16")
    tmp = os.path.join(outdir, "_cand.wav")

    for i, ln in enumerate(lines):
        if args.only and ln["id"] != args.only:
            continue
        kw = dict(language_id=args.lang, exaggeration=args.exag,
                  cfg_weight=CFG_WEIGHT, temperature=TEMPERATURE)
        if args.ref:
            kw["audio_prompt_path"] = args.ref
        best = None
        for k in range(args.n):
            seed_all(args.seed + i * 100 + k)
            text = ln.get(args.lang + "_say", ln[args.lang])
            wav = trim(model.generate(text, **kw).cpu(), model.sr)
            ta.save(tmp, wav, model.sr)
            segs, _ = asr.transcribe(tmp, language=args.lang, beam_size=5, word_timestamps=True)
            segs = list(segs)
            heard = " ".join(s.text.strip() for s in segs)
            score = similarity(ln[args.lang], heard) - choppy(segs)
            print(f"   {ln['id']} cand {k}: {score:.3f}  {heard}", flush=True)
            if best is None or score > best[0]:
                best = (score, wav, heard)
            if score >= 0.995 and k >= 1:
                break
        score, wav, heard = best
        path = os.path.join(outdir, ln["id"] + ".wav")
        ta.save(path, wav, model.sr)
        dur = wav.shape[1] / model.sr
        meta[ln["id"]] = round(dur, 3)
        print(f"{ln['id']:8s} {dur:5.2f}s  score {score:.3f}", flush=True)
    if os.path.exists(tmp):
        os.remove(tmp)

    json.dump(meta, open(meta_path, "w"), indent=1)
    print("total", round(sum(meta.values()), 2), "s")


if __name__ == "__main__":
    main()
