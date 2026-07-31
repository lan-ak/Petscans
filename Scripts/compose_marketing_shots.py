#!/usr/bin/env python3
"""Compose raw App Store screenshots into Yuka-style marketing frames.

Each output = branded green canvas + bold headline caption + the app
screenshot below with rounded corners and a soft shadow. On-brand green
(#34C759, ColorTokens.brandPrimary) and the app's own Quicksand Bold.

Usage: compose_marketing_shots.py <raw_dir> <out_dir> <W> <H>
"""
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAW, OUT, W, H = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])

FONT = "PetScans/Quicksand.ttf"
BRAND_TOP = (0x3F, 0xD0, 0x6A)   # slightly lighter green at top
BRAND_BOT = (0x2C, 0xA7, 0x4E)   # deeper green at bottom — subtle vertical gradient
WHITE = (255, 255, 255)

# (filename, caption) — captions are punchy two-liners, Yuka-style.
SHOTS = [
    ("01_HeroScore",        "Scan the bag.\nGet a score."),
    ("02_UnsafeIngredients", "See what's\nactually harmful"),
    ("03_AllergenAlert",    "Know what your\npet should avoid"),
    ("04_IngredientDetail", "Every ingredient,\nexplained"),
    ("05_Library",          "30,000+ foods\nbuilt in"),
    ("06_Sources",          "Backed by AAFCO,\nFDA & ASPCA"),
]


def load_bold(size):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name("Bold")
    except Exception:
        pass
    return f


def gradient(w, h, top, bot):
    base = Image.new("RGB", (w, h), top)
    draw = ImageDraw.Draw(base)
    for y in range(h):
        t = y / max(1, h - 1)
        draw.line(
            [(0, y), (w, y)],
            fill=tuple(round(top[i] + (bot[i] - top[i]) * t) for i in range(3)),
        )
    return base


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0], img.size[1]], radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def compose(raw_path, caption, out_path):
    canvas = gradient(W, H, BRAND_TOP, BRAND_BOT).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    # Headline — sized to the canvas, tightened line spacing like Yuka.
    fsize = round(W * 0.082)
    font = load_bold(fsize)
    lines = caption.split("\n")
    line_h = round(fsize * 1.12)
    top_margin = round(H * 0.055)
    for i, line in enumerate(lines):
        bbox = draw.textbbox((0, 0), line, font=font)
        lw = bbox[2] - bbox[0]
        x = (W - lw) / 2
        y = top_margin + i * line_h
        draw.text((x, y), line, font=font, fill=WHITE)

    # Device screenshot: ~82% width, top-aligned under the caption, bottom
    # allowed to run off-canvas so the phone reads as "in hand" (Yuka does this).
    shot = Image.open(raw_path).convert("RGB")
    target_w = round(W * 0.82)
    scale = target_w / shot.size[0]
    target_h = round(shot.size[1] * scale)
    shot = shot.resize((target_w, target_h), Image.LANCZOS)
    shot = rounded(shot, round(target_w * 0.055))

    shot_top = top_margin + len(lines) * line_h + round(H * 0.03)
    shot_x = (W - target_w) // 2

    # Soft drop shadow behind the device.
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = Image.new("RGBA", shot.size, (0, 0, 0, 90))
    sd.putalpha(shot.split()[-1].point(lambda a: int(a * 0.35)))
    shadow.paste(sd, (shot_x, shot_top + 18), sd)
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    canvas = Image.alpha_composite(canvas, shadow)

    canvas.paste(shot, (shot_x, shot_top), shot)
    canvas.convert("RGB").save(out_path, "PNG")


import os
os.makedirs(OUT, exist_ok=True)
for name, cap in SHOTS:
    compose(f"{RAW}/{name}.png", cap, f"{OUT}/{name}.png")
    print("composed", name)
