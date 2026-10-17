#!/usr/bin/env python3
"""Prueft die Play-Store-Texte gegen die Zeichengrenzen der Console.

App-Name <= 30, Kurzbeschreibung <= 80, Beschreibung <= 4000,
Release-Notes <= 500 je Sprache (Inhalt zwischen den Sprach-Tags).
Prueft ausserdem, ob alle referenzierten Grafiken existieren und die
Screenshots 1080x1920 gross sind.
"""
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
STORE = os.path.join(ROOT, "store")
ok = True


def blocks_after(text, heading):
    """Erster ```-Block nach einer Ueberschrift, die mit `heading` beginnt."""
    i = text.find(heading)
    if i < 0:
        return None
    m = re.search(r"```\n(.*?)\n```", text[i:], re.S)
    return m.group(1) if m else None


def check(label, value, limit):
    global ok
    n = len(value) if value is not None else -1
    status = "ok" if 0 < n <= limit else "ZU LANG" if n > limit else "FEHLT"
    if status != "ok":
        ok = False
    print(f"  {label:<26} {n:>5} / {limit:<5} {status}")


for lang, name_h, short_h, full_h in [
    ("de", "## App-Name", "## Kurzbeschreibung", "## Vollständige Beschreibung"),
    ("en", "## App name", "## Short description", "## Full description"),
]:
    text = open(os.path.join(STORE, f"listing-{lang}.md"), encoding="utf-8").read()
    print(f"listing-{lang}.md")
    check("App-Name", blocks_after(text, name_h), 30)
    check("Kurzbeschreibung", blocks_after(text, short_h), 80)
    check("Beschreibung", blocks_after(text, full_h), 4000)
    for ref in re.findall(r"`(store/[^`]+\.png)`", text):
        path = os.path.join(ROOT, ref)
        if not os.path.exists(path):
            ok = False
            print(f"  FEHLT: {ref}")
        elif "/screenshots/" in ref:
            try:
                from PIL import Image
                size = Image.open(path).size
                if size != (1080, 1920):
                    ok = False
                    print(f"  FALSCHE GROESSE {size}: {ref}")
            except ImportError:
                pass

notes = open(os.path.join(STORE, "release-notes-template.md"), encoding="utf-8").read()
first = notes[notes.find("## 0.5.0"):]
print("release-notes-template.md (0.5.0)")
for tag in ["de-DE", "en-US"]:
    m = re.search(rf"<{tag}>\n(.*?)\n</{tag}>", first, re.S)
    check(f"Release-Notes {tag}", m.group(1) if m else None, 500)

print("OK" if ok else "FEHLER")
sys.exit(0 if ok else 1)
