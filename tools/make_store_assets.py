#!/usr/bin/env python3
"""Erzeugt die Google-Play-Store-Grafiken fuer Macro Lens.

- store/icon-512.png            (512x512, randlos, kein Alpha)
- store/feature-graphic-1024x500.png (1024x500, kein Alpha)
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


def make_feature(width=1024, height=500):
    img = Image.new("RGB", (width, height), BG)
    d = ImageDraw.Draw(img)
    # dezente Linien
    d.line([(0, height - 1), (width, height - 1)], fill=LINE, width=2)
    # Donut links
    donut(img, 250, height / 2, 118, 42, [(0.32, PROTEIN), (0.43, CARBS), (0.25, FAT)])
    f_big = font("OpenSans-Bold.ttf", 76)
    f_sm = font("OpenSans-Regular.ttf", 30)
    d.text((430, height / 2 - 74), "MACRO", font=f_big, fill=TEXT)
    w_macro = d.textlength("MACRO", font=f_big)
    d.text((430 + w_macro, height / 2 - 74), " LENS", font=f_big, fill=AMBER)
    d.text((432, height / 2 + 18), "Vier Grafiken statt Nährwerttabelle", font=f_sm, fill=TEXT)
    d.text((432, height / 2 + 58), "Scan · Eiweiß/kcal · Sättigung · Vergleich", font=f_sm, fill=MUTED)
    img.save(os.path.join(OUT, "feature-graphic-1024x500.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make_icon()
    make_feature()
    print("store graphics written to", os.path.normpath(OUT))
