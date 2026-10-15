#!/usr/bin/env python3
"""Erzeugt die App-Icons fuer Macro Lens (Donut-Motiv, dunkler Grund)."""
from PIL import Image, ImageDraw
import math, os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons")
BG = (16, 18, 20, 255)
BG_EDGE = (23, 25, 28, 255)
PROTEIN = (76, 141, 246, 255)
CARBS = (240, 160, 32, 255)
FAT = (229, 104, 77, 255)
LINE = (42, 46, 52, 255)

def draw_donut(size, ring_w, cx_frac=0.5, cy_frac=0.5, radius_frac=0.30):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = size * cx_frac, size * cy_frac
    r = size * radius_frac
    w = ring_w
    box = [cx - r, cy - r, cx + r, cy + r]
    start = -90.0
    segs = [(0.32, PROTEIN), (0.43, CARBS), (0.25, FAT)]
    gap = 3.5
    for frac, col in segs:
        span = frac * 360.0
        d.arc(box, start + gap / 2, start + span - gap / 2, fill=col, width=w)
        start += span
    return img

def rounded_bg(size, radius_frac=0.22):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = 0
    r = int(size * radius_frac)
    d.rounded_rectangle([m, m, size - 1 - m, size - 1 - m], radius=r, fill=BG)
    return img

def make_full(size):
    base = rounded_bg(size)
    ring = draw_donut(size, ring_w=int(size * 0.105), radius_frac=0.30)
    base.alpha_composite(ring)
    return base

def make_fg(size):
    # Adaptive Foreground: Motiv innerhalb der Safe-Zone (~66 %)
    return draw_donut(size, ring_w=int(size * 0.075), radius_frac=0.22)

def make_bg(size):
    return Image.new("RGBA", (size, size), BG_EDGE)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for s in (512, 256, 192, 144, 96, 72, 48):
        make_full(s).save(os.path.join(OUT, f"icon-{s}.png"))
    make_fg(432).save(os.path.join(OUT, "adaptive_fg_432.png"))
    make_bg(432).save(os.path.join(OUT, "adaptive_bg_432.png"))
    make_full(512).save(os.path.join(OUT, "icon.png"))
    print("icons written to", os.path.normpath(OUT))
