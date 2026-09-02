#!/usr/bin/env python3
"""Compose raw App Store screenshots into marketing frames.

The framing follows what Yuka's store page does, which is the thing that makes a
screenshot survive being shrunk to the 320x480 thumbnail the store serves in
search results:

  1. No device and no navigation. The status bar, the navigation bar and the tab bar
     are all cropped away before the shot is placed, so none of the canvas is spent
     on chrome that sells nothing. A back chevron, a "Scan Details" title and a
     share/star pill are not the product, and the blurred backdrop material behind
     them renders as grey smudging on a marketing frame.
  2. One card is lifted out. Each shot names a single card — the rating badge, the
     BHA/BHT warning, the allergen alert — which is cropped from the raw capture and
     floated over the panel, enlarged and shadowed. One thing to look at instead of
     six competing for the same 320 pixels.
  3. Every cut lands between elements. The float's edges and the panel's bottom are
     snapped to the gutters between cards, so nothing is ever sliced through the
     middle. See `row_profile` for why "the quietest row" is the wrong test.
  4. Leftover space is shared. Snapping a cut upward shortens the panel, and the
     slack is split above and below rather than dumped underneath.

Where the card sits is not guessed here. `ScreenshotTests` records each float's
frame, normalised to the window, into `<shot>.floats.json` beside the PNG, so one
set of coordinates works at every device size.

Usage: compose_marketing_shots.py <raw_dir> <out_dir> <W> <H>
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAW, OUT, W, H = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])

FONT = "PetScans/Quicksand.ttf"
BRAND_TOP = (0x3F, 0xD0, 0x6A)   # slightly lighter green at top
BRAND_BOT = (0x2C, 0xA7, 0x4E)   # deeper green at bottom — subtle vertical gradient
WHITE = (255, 255, 255)

# Fractions of the raw capture to cut before the shot is placed. The top figure
# clears the status bar *and* the navigation bar, so the frame opens on content
# rather than on a back button; the bottom clears the floating tab bar. Both are
# per shot, because what counts as chrome differs: the sheet in shot 4 has its own
# header, and the References screen's title is content worth keeping.
CROP_TOP = 0.115
CROP_BOTTOM = 0.100
# Shaves the scroll indicator off the right edge. Taken off both sides so the
# content stays centred; nothing in these screens lives in the outer 2%.
CROP_SIDE = 0.018

# (filename, caption, crop_top, crop_bottom)
SHOTS = [
    ("01_HeroScore",         "Scan the bag.\nGet a score.",        CROP_TOP, CROP_BOTTOM),
    ("02_UnsafeIngredients", "See what's\nactually harmful",       CROP_TOP, CROP_BOTTOM),
    ("03_AllergenAlert",     "Know what your\npet should avoid",   CROP_TOP, CROP_BOTTOM),
    # Opens on "BHA — Caution" instead of on the sheet's title bar and Done button.
    ("04_IngredientDetail",  "Every ingredient,\nexplained",       0.148,    0.020),
    ("05_Library",           "30,000+ foods\nbuilt in",            CROP_TOP, CROP_BOTTOM),
    ("06_Sources",           "No brand pays us\nto score anything", CROP_TOP, CROP_BOTTOM),
]

# Layout, as fractions of the output canvas.
CAPTION_TOP = 0.050
PANEL_GAP = 0.030          # caption block to panel
PANEL_WIDTH = 0.94
PANEL_BOTTOM = 0.040       # green left under the panel
FLOAT_WIDTH = 0.99         # wider than the panel, so the card breaks both edges
FLOAT_MAX_SCALE = 1.55     # a lift, not a blow-up: a narrow card grows, it does not fill
FLOAT_PAD = 0.008          # bleed added around the recorded frame, in panel widths
FLOAT_SNAP = 0.05          # how far the float may slide to land its edges in a gutter


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


def drop_shadow(canvas, layer, xy, blur, alpha, offset):
    """Composite `layer`'s silhouette under it as a blurred shadow."""
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    body = Image.new("RGBA", layer.size, (0, 0, 0, alpha))
    body.putalpha(layer.split()[-1].point(lambda a: int(a * alpha / 255)))
    shadow.paste(body, (xy[0], xy[1] + offset), body)
    return Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(blur)))


def draw_caption(canvas, caption):
    """Returns the y at which the caption block ends."""
    draw = ImageDraw.Draw(canvas)
    fsize = round(W * 0.082)
    font = load_bold(fsize)
    lines = caption.split("\n")
    line_h = round(fsize * 1.12)
    top = round(H * CAPTION_TOP)
    for i, line in enumerate(lines):
        bbox = draw.textbbox((0, 0), line, font=font)
        x = (W - (bbox[2] - bbox[0])) / 2 - bbox[0]
        draw.text((x, top + i * line_h), line, font=font, fill=WHITE)
    return top + len(lines) * line_h


def float_card(shot, rect):
    """Crop the recorded card out of the raw capture, with a little bleed."""
    sw, sh = shot.size
    pad_x = round(sw * FLOAT_PAD)
    pad_y = round(sh * FLOAT_PAD * (sw / sh))
    box = (
        max(0, round(rect["x"] * sw) - pad_x),
        max(0, round(rect["y"] * sh) - pad_y),
        min(sw, round((rect["x"] + rect["w"]) * sw) + pad_x),
        min(sh, round((rect["y"] + rect["h"]) * sh) + pad_y),
    )
    return shot.crop(box), box


def row_profile(img, x0, x1):
    """Two per-row measures of an app screen: how busy the row is, and how much of
    it is bare page background.

    Busy-ness alone is not enough to place a cut. The flat middle of a warning card
    is every bit as quiet as the gutter between two cards, so a "quietest row" search
    happily slices a card in half — which is what put a sliver of the Avoid badge at
    the bottom of shot 3 and cut Ingredient Recognition through the middle in shot 2.

    Background coverage tells the two apart. The page colour is sampled from the left
    gutter, where cards do not reach; a row that is almost entirely that colour is a
    real gap between elements, and a row inside a card is not, however flat it is.
    """
    rgb = np.asarray(img.convert("RGB"), dtype=np.int16)
    gutter = rgb[:, : max(2, rgb.shape[1] // 40)]
    page = np.median(gutter.reshape(-1, 3), axis=0)

    x0 = max(0, min(x0, rgb.shape[1] - 1))
    x1 = max(x0 + 1, min(x1, rgb.shape[1]))
    strip = rgb[:, x0:x1]

    background = (np.abs(strip - page).max(axis=2) <= 12).mean(axis=1)

    grey = strip.mean(axis=2)
    activity = np.abs(grey - np.median(grey, axis=1, keepdims=True)).mean(axis=1)
    activity = activity / max(1.0, float(activity.max()))

    return background, activity


def _edge_cost(profile, edge, band):
    background, activity = profile
    lo = max(0, edge - band)
    hi = min(len(activity), edge + band + 1)
    if hi <= lo:
        return 0.0
    # Being off a card dominates; quietness only breaks ties between gutters.
    return (1.0 - float(background[lo:hi].min())) * 10.0 + float(activity[lo:hi].mean())


def snap_edge(profile, edge, up, down, band):
    """Move a single cut to the nearest gap between elements.

    The two limits are deliberately lopsided for the panel's bottom cut: moving it up
    only trims content and grows the green margin, while moving it down risks running
    into the tab bar. So it may travel a long way up to reach a gutter and barely any
    way down.
    """
    best, best_cost = edge, None
    for candidate in range(max(0, edge - up), min(len(profile[1]), edge + down + 1)):
        cost = _edge_cost(profile, candidate, band) + abs(candidate - edge) * 0.002
        if best_cost is None or cost < best_cost:
            best, best_cost = candidate, cost
    return best


def snap_band(profile, top, height, limit, band):
    """Slide a float so both its edges land between elements, not through them.

    A card enlarged over the screen it came from spills past the row it replaces, and
    wherever its edge lands it cuts whatever is underneath. Half a word showing above
    a floated card is the single thing that makes one of these frames look broken
    rather than composed.
    """
    best, best_cost = top, None
    for shift in range(-limit, limit + 1):
        t, b = top + shift, top + height + shift
        if t < 0 or b >= len(profile[1]):
            continue
        # A small penalty on distance keeps the card near its source when several
        # offsets are equally clean.
        cost = _edge_cost(profile, t, band) + _edge_cost(profile, b, band) + abs(shift) * 0.002
        if best_cost is None or cost < best_cost:
            best, best_cost = top + shift, cost
    return best


def compose(name, caption, crop_top, crop_bottom, out_path):
    raw_path = os.path.join(RAW, f"{name}.png")
    shot = Image.open(raw_path).convert("RGB")
    sw, sh = shot.size

    canvas = gradient(W, H, BRAND_TOP, BRAND_BOT).convert("RGBA")
    caption_bottom = draw_caption(canvas, caption)

    # --- panel: the app screen with its chrome cut off ---
    panel_w = round(W * PANEL_WIDTH)
    panel_x = (W - panel_w) // 2
    panel_y = round(caption_bottom + H * PANEL_GAP)

    src_x0 = round(sw * CROP_SIDE)
    src_x1 = sw - src_x0
    src_top = round(sh * crop_top)

    # How much of the screen fits between the caption and the bottom margin. The
    # panel used to run to a fixed crop and stop wherever that landed, which put its
    # rounded bottom edge through the middle of a card. Size it to the space
    # instead, then move the cut to the nearest quiet row so it lands between
    # elements.
    want_h = (H - round(H * PANEL_BOTTOM)) - panel_y
    src_h = round(want_h * (src_x1 - src_x0) / panel_w)
    src_limit = round(sh * (1 - crop_bottom))
    src_bottom = min(src_top + src_h, src_limit)

    below = shot.crop((src_x0, src_top, src_x1, src_limit))
    src_bottom = src_top + snap_edge(
        row_profile(below, 0, src_x1 - src_x0),
        src_bottom - src_top,
        # Far enough up to clear a whole element: the Avoid badge on shot 3 and the
        # Ingredient Recognition card on shot 2 are both taller than a short search
        # could escape, and a cut inside either reads as a rendering fault.
        round(sh * 0.120),
        round(sh * 0.015),
        max(2, round(sh * 0.002)),
    )
    src_bottom = min(src_bottom, src_limit)

    panel = shot.crop((src_x0, src_top, src_x1, src_bottom))
    panel_h = round(panel.size[1] * panel_w / panel.size[0])
    panel = panel.resize((panel_w, panel_h), Image.LANCZOS)

    # Snapping the cut up to a gutter leaves the panel shorter than the space it was
    # sized for. Split what is left over between the caption and the bottom margin
    # instead of dumping all of it underneath, so the panel sits balanced in the
    # frame rather than looking like it ran out.
    slack = (H - round(H * PANEL_BOTTOM)) - (panel_y + panel_h)
    if slack > 0:
        panel_y += round(slack * 0.5)
    panel_rgb = panel.copy()          # pre-alpha, for the whitespace scan below
    panel = rounded(panel, round(panel_w * 0.045))

    canvas = drop_shadow(canvas, panel, (panel_x, panel_y), blur=30, alpha=90, offset=18)
    canvas.paste(panel, (panel_x, panel_y), panel)

    # --- float: one card lifted out of that same screen ---
    rect_path = os.path.join(RAW, f"{name}.floats.json")
    if os.path.exists(rect_path):
        with open(rect_path) as fh:
            rect = json.load(fh)["card"]

        card, box = float_card(shot, rect)

        # Grow the card toward the canvas width, but cap the growth. A rating badge
        # is 40% of the screen wide; blown up to fill the frame it stops reading as a
        # card lifted off a screen and starts reading as a zoomed screenshot.
        panel_scale = panel_w / (src_x1 - src_x0)
        scale = min(W * FLOAT_WIDTH / card.size[0], FLOAT_MAX_SCALE * panel_scale)
        card_w = round(card.size[0] * scale)
        card_h = round(card.size[1] * scale)
        card = card.resize((card_w, card_h), Image.LANCZOS)

        # White matte behind the crop, so a card with a tinted or translucent
        # background still reads as a card rather than as a torn-out rectangle.
        matte = Image.new("RGB", card.size, WHITE)
        matte.paste(card, (0, 0))
        card = rounded(matte, round(card_w * 0.035))

        # Sit the enlargement on top of the row it was cut from, centred on it. Placed
        # anywhere else the card reads as a duplicate of something still visible below
        # it; placed here it reads as that row lifted off the screen.
        source_y = panel_y + (box[1] - src_top) * panel_scale
        source_h = (box[3] - box[1]) * panel_scale
        card_x = (W - card_w) // 2
        card_y = round(source_y - (card_h - source_h) / 2)

        # Then slide it so its edges fall between lines rather than through them.
        card_y = panel_y + snap_band(
            row_profile(panel_rgb, card_x - panel_x, card_x - panel_x + card_w),
            card_y - panel_y,
            card_h,
            round(H * FLOAT_SNAP),
            max(2, card_h // 60),
        )
        card_y = max(round(caption_bottom + H * 0.02), min(card_y, round(H - card_h * 0.55)))

        canvas = drop_shadow(canvas, card, (card_x, card_y), blur=26, alpha=120, offset=20)
        canvas.paste(card, (card_x, card_y), card)

    # RGB with an explicit 72 dpi. App Store Connect rejects screenshots carrying an
    # alpha channel, and has rejected ones whose embedded resolution is not 72.
    canvas.convert("RGB").save(out_path, "PNG", dpi=(72, 72))


os.makedirs(OUT, exist_ok=True)
for name, cap, ct, cb in SHOTS:
    compose(name, cap, ct, cb, f"{OUT}/{name}.png")
    print("composed", name)
