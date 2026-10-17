#!/usr/bin/env python3
"""Erzeugt die Google-Play-Store-Grafiken fuer Macro Lens.

- store/icon-512.png            (512x512, randlos, kein Alpha)
- store/feature-graphic-1024x500.png    (1024x500, kein Alpha, deutsch)
- store/feature-graphic-1024x500-en.png (1024x500, kein Alpha, englisch)
"""
from PIL import Image, ImageDraw, ImageFont
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "store")
FONTS = os.path.join(ROOT, "assets", "fonts")

BG = (16, 18, 20, 255)
SURF = (23, 25, 28, 255)
LINE = (42, 46, 52, 255)
TEXT = (236, 238, 240, 255)
MUTED = (139, 145, 153, 255)
AMBER = (240, 160, 32, 255)
PROTEIN = (76, 141, 246, 255)
CARBS = (240, 160, 32, 255)
FAT = (229, 104, 77, 255)
SUGAR = (232, 121, 168, 255)
BAD = (229, 72, 77, 255)
INTOL = (242, 140, 40, 255)

TEXTS = {
    "de": ("Im Supermarkt schneller besser wählen", "Scannen · Vergleichen · Allergene im Blick",
           "feature-graphic-1024x500.png"),
    "en": ("Faster, better supermarket choices", "Scan · Compare · Spot allergens",
           "feature-graphic-1024x500-en.png"),
}


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def donut(img, cx, cy, r, w, segs, gap_deg=3.0):
    d = ImageDraw.Draw(img)
    box = [cx - r, cy - r, cx + r, cy + r]
    start = -90.0
    for frac, col in segs:
        span = frac * 360.0
        d.arc(box, start + gap_deg / 2, start + span - gap_deg / 2, fill=col, width=w)
        start += span


def make_icon(size=512):
    img = Image.new("RGB", (size, size), BG)
    donut(img, size / 2, size / 2, size * 0.30, int(size * 0.105),
          [(0.32, PROTEIN), (0.43, CARBS), (0.25, FAT)])
    img.save(os.path.join(OUT, "icon-512.png"))


def make_feature(lang="de", width=1024, height=500):
    line1, line2, name = TEXTS[lang]
    img = Image.new("RGB", (width, height), BG)
    d = ImageDraw.Draw(img)
    d.line([(0, height - 1), (width, height - 1)], fill=LINE, width=2)
    # Donut links (mit Zucker-Anteil wie in der App)
    donut(img, 250, height / 2, 118, 42,
          [(0.30, PROTEIN), (0.16, SUGAR), (0.29, CARBS), (0.25, FAT)])
    f_big = font("OpenSans-Bold.ttf", 76)
    x0 = 430
    size = 30
    while size > 20:   # beide Zeilen mit 40 px Rand rechts
        f_sm = font("OpenSans-Regular.ttf", size)
        if max(d.textlength(line1, font=f_sm), d.textlength(line2, font=f_sm)) <= width - x0 - 42:
            break
        size -= 1
    f_chip = font("OpenSans-Bold.ttf", 20)
    d.text((x0, height / 2 - 92), "MACRO", font=f_big, fill=TEXT)
    w_macro = d.textlength("MACRO", font=f_big)
    d.text((x0 + w_macro, height / 2 - 92), " LENS", font=f_big, fill=AMBER)
    d.text((x0 + 2, height / 2 + 4), line1, font=f_sm, fill=TEXT)
    d.text((x0 + 2, height / 2 + 44), line2, font=f_sm, fill=MUTED)
    # zwei Warn-Chips wie auf der Hauptseite
    chips = [("ALLERGEN", BAD), ("UNVERTR." if lang == "de" else "INTOL.", INTOL)]
    cx = x0 + 2
    for label, col in chips:
        tw = d.textlength(label, font=f_chip)
        d.rounded_rectangle([cx, height / 2 + 104, cx + tw + 24, height / 2 + 138], radius=4, fill=col)
        d.text((cx + 12, height / 2 + 107), label, font=f_chip, fill=(20, 21, 20))
        cx += tw + 40
    img.save(os.path.join(OUT, name))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make_icon()
    make_feature("de")
    make_feature("en")
    print("store graphics written to", os.path.normpath(OUT))
