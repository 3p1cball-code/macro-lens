"""Tonspur des Store-Videos: synthetische Musik + Geraeusche + Sprecher.

Aufruf:  python mix.py de   (liest out/plan_de.json, out/vo/de/*.wav)
Ausgabe: out/audio_de.wav (48 kHz Stereo, unnormiert; Lautheit macht ffmpeg loudnorm)

Alles deterministisch (fester Seed). Musik: ruhiger Loop, 92 BPM,
Cmaj7 – Am7 – Fmaj7 – G6, Marimba-Arpeggio, weiches Pad, Sinus-Bass,
leise Off-Beat-Klicks. Unter dem Sprecher wird die Musik abgesenkt (Ducking).
"""
import json
import os
import sys

import numpy as np
import soundfile as sf

SR = 48000
HERE = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def env_ad(n, a, d):
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / d)
    return e


def onepole_lp(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    acc = 0.0
    # vektorisiert ueber scipy waere schneller; Laenge ist klein genug
    from scipy.signal import lfilter
    return lfilter([1 - a], [1, -a], x)


def place(buf, sig, at, gain=1.0, pan=0.0):
    i = int(round(at * SR))
    if i >= len(buf):
        return
    if i < 0:
        sig = sig[-i:]
        i = 0
    n = min(len(sig), len(buf) - i)
    l = np.cos((pan + 1) * np.pi / 4)
    r = np.sin((pan + 1) * np.pi / 4)
    if sig.ndim == 1:
        buf[i:i + n, 0] += sig[:n] * gain * l * 1.414
        buf[i:i + n, 1] += sig[:n] * gain * r * 1.414
    else:
        buf[i:i + n] += sig[:n] * gain


# ---------------------------------------------------------------------------
# Instrumente
# ---------------------------------------------------------------------------
def marimba(f, dur=0.9):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.35)
    s += 0.35 * np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t / 0.05)
    s += 0.12 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t / 0.015)
    return s * np.minimum(1, t / 0.002)


def epiano(f, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    mod = 1.2 * np.exp(-t / 0.4) * np.sin(2 * np.pi * f * t)
    s = np.sin(2 * np.pi * f * t + mod) * np.exp(-t / 1.6)
    return s * np.minimum(1, t / 0.004) * np.minimum(1, (dur - t) / 0.08).clip(0)


def pad(freqs, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for f in freqs:
        for det in (-0.12, 0.12):
            ph = rng.uniform(0, 2 * np.pi)
            ff = f * 2 ** (det / 12)
            # weiche Saege (wenige Obertoene)
            for k in range(1, 6):
                s += np.sin(2 * np.pi * ff * k * t + ph * k) / k ** 1.6
    s = onepole_lp(s, 1100)
    att = np.minimum(1, t / 0.6)
    rel = np.minimum(1, (dur - t) / 0.6).clip(0)
    return s * att * rel / (len(freqs) * 4)


def bass(f, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t)
    return s * np.minimum(1, t / 0.01) * np.exp(-t / 0.9) * np.minimum(1, (dur - t) / 0.05).clip(0)


def click(dur=0.05, fc=7000):
    n = int(dur * SR)
    x = rng.standard_normal(n) * np.exp(-np.arange(n) / SR / 0.008)
    from scipy.signal import butter, lfilter
    b, a = butter(2, fc / (SR / 2), 'high')
    return lfilter(b, a, x)


def music(total, end_at):
    bpm = 92.0
    beat = 60 / bpm
    bar = 4 * beat
    out = np.zeros((int((total + 3) * SR), 2))
    # Akkorde (Grundton, Akkordtoene) – C-Dur, ruhig
    prog = [(48, [60, 64, 67, 71]), (45, [57, 60, 64, 67]), (41, [57, 60, 65, 69]), (43, [59, 62, 67, 69])]
    arp_pat = [0, 2, 1, 3, 2, 1, 3, 2]
    nbars = int(np.ceil(end_at / bar))
    for b in range(nbars):
        t0 = b * bar
        root, tones = prog[b % 4]
        intro = b == 0
        place(out, pad([midi(n) for n in tones], bar + 0.6), t0, 0.22)
        place(out, bass(midi(root), beat * 1.9), t0, 0.32)
        place(out, bass(midi(root + 7 if b % 2 else root), beat * 1.9), t0 + 2 * beat, 0.26)
        if not intro:
            for i in range(8):
                n = tones[arp_pat[i]] + 12
                place(out, marimba(midi(n)), t0 + i * beat / 2, 0.11 if i % 2 else 0.15, pan=-0.35 + 0.1 * i)
        # Off-Beat-Klick + leiser Shaker
        if b >= 1:
            for i in range(4):
                place(out, click(), t0 + i * beat + beat / 2, 0.05, pan=0.3)
        if b % 4 == 3:
            place(out, epiano(midi(tones[3] + 12), beat * 3), t0 + beat, 0.07, pan=0.2)
    # Schluss: aufgeloester C-Akkord + Ausklang
    tones = [60, 64, 67, 72]
    place(out, pad([midi(n) for n in tones], 4.0), end_at, 0.24)
    place(out, bass(midi(36), 3.0), end_at, 0.35)
    for i, n in enumerate([72, 76, 79, 84]):
        place(out, epiano(midi(n), 3.0), end_at + i * 0.09, 0.09, pan=-0.3 + 0.2 * i)
    # Musik bis zum Akkordwechsel ausblenden (vor dem Schlussakkord)
    t = np.arange(len(out)) / SR
    fade = np.clip((end_at + 0.05 - t) / 0.35, 0, 1)
    fade = np.where(t >= end_at, 1.0, fade)
    out *= fade[:, None]
    # Gesamt-Ausblende
    out *= np.clip((total - t) / 1.8, 0, 1)[:, None]
    return out[: int(total * SR)]


# ---------------------------------------------------------------------------
# Geraeusche
# ---------------------------------------------------------------------------
def sfx(name, rate=1.0):
    from scipy.signal import butter, lfilter
    if name == 'tick':       # Haptik/Scan-Bestaetigung
        n = int(0.03 * SR); t = np.arange(n) / SR
        return np.sin(2 * np.pi * 2400 * rate * t) * np.exp(-t / 0.006)
    if name == 'tap':
        n = int(0.05 * SR); t = np.arange(n) / SR
        return 0.6 * np.sin(2 * np.pi * 900 * t) * np.exp(-t / 0.01) + 0.4 * click(0.05, 3000)
    if name in ('pop', 'build', 'soft'):
        dur = {'pop': 0.12, 'build': 0.18, 'soft': 0.2}[name]
        n = int(dur * SR); t = np.arange(n) / SR
        f0 = {'pop': 520, 'build': 660, 'soft': 880}[name] * rate
        f = f0 * (1 + 0.6 * np.exp(-t / 0.02))
        ph = 2 * np.pi * np.cumsum(f) / SR
        g = np.exp(-t / (0.035 if name == 'pop' else 0.06))
        return np.sin(ph) * g * np.minimum(1, t / 0.002)
    if name == 'pin':        # Einrasten: zwei kurze Toene aufwaerts
        a = sfx('build', 1.0)
        b = sfx('build', 1.5)
        out = np.zeros(int(0.3 * SR)); out[:len(a)] += a; out[int(0.07 * SR):int(0.07 * SR) + len(b)] += b * 0.8
        return out
    if name in ('whoosh', 'whooshup', 'zoom'):
        dur = {'whoosh': 0.45, 'whooshup': 0.35, 'zoom': 1.3}[name] / rate
        n = int(dur * SR); t = np.arange(n) / SR
        x = rng.standard_normal(n)
        y = np.zeros(n)
        # gleitender Bandpass (in Bloecken)
        blk = 512
        for i in range(0, n, blk):
            k = i / n
            fc = (400 + 3000 * (k if name != 'whoosh' else 1 - abs(2 * k - 1))) * rate
            b, a = butter(2, [max(80, fc * 0.6) / (SR / 2), min(fc * 1.6, 20000) / (SR / 2)], 'band')
            y[i:i + blk] = lfilter(b, a, x[i:i + blk])
        e = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2
        return y * e * 0.6
    if name == 'fall':       # kleiner Fall-Pfiff
        n = int(0.7 * SR); t = np.arange(n) / SR
        f = 1400 * np.exp(-t / 0.5)
        return 0.3 * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.4)
    if name == 'pen':        # Rotstift-Kringel
        n = int(0.75 * SR); t = np.arange(n) / SR
        x = rng.standard_normal(n)
        b, a = butter(2, [1800 / (SR / 2), 6000 / (SR / 2)], 'band')
        y = lfilter(b, a, x) * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * t)) * np.sin(np.pi * t / 0.75)
        return y * 0.5
    if name == 'steps':      # Ameisen-Trippeln
        out = np.zeros(int(1.4 * SR))
        for i in range(18):
            s = sfx('tick', 1.6 + 0.2 * (i % 3)) * 0.5
            j = int(i * 0.075 * SR); out[j:j + len(s)] += s
        return out
    if name == 'chime':
        out = np.zeros(int(2.5 * SR))
        for i, n in enumerate([84, 88, 91]):
            s = marimba(midi(n), 2.0) * 0.6
            j = int(i * 0.08 * SR); out[j:j + len(s)] += s
        return out
    raise ValueError(name)


def load_vo(path):
    x, sr = sf.read(path, dtype='float64')
    if x.ndim > 1:
        x = x.mean(axis=1)
    if sr != SR:
        from scipy.signal import resample_poly
        g = np.gcd(sr, SR)
        x = resample_poly(x, SR // g, sr // g)
    # nur normieren + weiche Ein-/Ausblende (keine Saettigung -> keine Verzerrung)
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.9
    f = int(0.012 * SR)
    ramp = np.linspace(0, 1, f)
    x[:f] *= ramp
    x[-f:] *= ramp[::-1]
    return x


def main():
    lang = sys.argv[1] if len(sys.argv) > 1 else 'de'
    plan = json.load(open(os.path.join(HERE, 'out', f'plan_{lang}.json')))
    total = plan['duration']
    n = int(total * SR)
    end_at = plan['scenes']['end']['t0'] + 0.2

    mus = music(total, end_at)
    voice = np.zeros((n, 2))
    duck = np.zeros(n)
    for v in plan['vo']:
        p = os.path.join(HERE, 'out', 'vo', lang, v['id'] + '.wav')
        x = load_vo(p)
        place(voice, x, v['at'], 1.0)
        i0 = int(v['at'] * SR); i1 = min(n, i0 + len(x))
        duck[max(0, i0 - int(0.15 * SR)):i1 + int(0.25 * SR)] = 1.0
    # Ducking-Huellkurve glaetten
    from scipy.signal import lfilter
    a = np.exp(-1 / (0.12 * SR))
    duck = lfilter([1 - a], [1, -a], duck)
    mus *= (1 - 0.55 * duck)[:, None]

    fx = np.zeros((n, 2))
    for s in plan['sfx']:
        place(fx, sfx(s['name'], s.get('rate', 1.0)), s['at'], 0.5 * s.get('gain', 1.0), pan=0.0)

    mix = 0.55 * mus + 1.0 * voice + 0.7 * fx
    peak = np.max(np.abs(mix))
    mix = mix / max(peak, 1e-9) * 0.89
    out = os.path.join(HERE, 'out', f'audio_{lang}.wav')
    sf.write(out, mix.astype(np.float32), SR)
    print(out, f'{total:.2f}s', 'peak', round(float(peak), 3))


if __name__ == '__main__':
    main()
