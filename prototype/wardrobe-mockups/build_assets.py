#!/usr/bin/env python3
"""PROTOTYPE asset cutter for the wardrobe mockups: V and the visible item icons, cut from
the 2026-10-14 wardrobe screenshot. Stand-in icons for other slots and the world backdrop
are copied from ../inventory-mockups/assets.

Usage: python3 prototype/wardrobe-mockups/build_assets.py [screenshot.jpg]
Coordinates are in the 2000x1125 display space of the screenshot; S maps them to its
native 2560x1440 pixels.
"""
import colorsys
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
SRC = Path(sys.argv[1] if len(sys.argv) > 1 else
           Path.home() / ".local/share/Steam/userdata/82605613/760/remote/1091500/screenshots/20261014095702_1.jpg")
OUT = HERE / "assets"
INV = HERE.parent / "inventory-mockups" / "assets"
S = 1.28

im = Image.open(SRC).convert("RGB")
OUT.mkdir(exist_ok=True)
im.save(OUT / "current.jpg", quality=90)


def box(x0, y0, x1, y1):
    return tuple(round(v * S) for v in (x0, y0, x1, y1))


# Empty backdrop areas used to fit the menu's gradient (display units).
BACKDROP = [(850, 140, 1170, 480), (860, 560, 1170, 1000), (290, 200, 395, 1000),
            (40, 200, 260, 1000), (300, 122, 420, 180), (820, 122, 1170, 180)]
TERMS = [(i, j) for i in range(5) for j in range(5 - i)]


def design(xs, ys):
    return np.stack([(xs / 2560) ** i * (ys / 1440) ** j for i, j in TERMS], axis=-1)


def fit_backdrop():
    full = np.asarray(im, dtype=np.float32)
    xs, ys = [], []
    for r in BACKDROP:
        x0, y0, x1, y1 = box(*r)
        gy, gx = np.mgrid[y0:y1:4, x0:x1:4]
        xs.append(gx.ravel()); ys.append(gy.ravel())
    xs = np.concatenate(xs).astype(np.float32); ys = np.concatenate(ys).astype(np.float32)
    samples = full[ys.astype(int), xs.astype(int)]
    coef, *_ = np.linalg.lstsq(design(xs, ys), samples, rcond=None)
    rms = np.sqrt(np.mean((design(xs, ys) @ coef - samples) ** 2))
    print("backdrop fit rms", round(float(rms), 2))
    return coef


def matte(crop_box, clear):
    """Key V off the fitted backdrop. `clear` boxes (display units) are forced transparent:
    UI text that overlaps the crop."""
    coef = fit_backdrop()
    x0, y0, x1, y1 = box(*crop_box)
    rgb = np.asarray(im.crop((x0, y0, x1, y1)), dtype=np.float32)
    h, w = rgb.shape[:2]
    gy, gx = np.mgrid[0:h, 0:w]
    bg = (design((gx + x0).astype(np.float32), (gy + y0).astype(np.float32)) @ coef).reshape(h, w, 3)
    for c in clear:
        cx0, cy0, cx1, cy1 = box(*c)
        rgb[max(0, cy0 - y0):cy1 - y0, max(0, cx0 - x0):cx1 - x0] = bg[max(0, cy0 - y0):cy1 - y0, max(0, cx0 - x0):cx1 - x0]
    d = np.sqrt(((rgb - bg) ** 2).sum(-1))
    a = np.clip((d - 10) / 26, 0, 1)
    solid = Image.fromarray(((a > 0.35) * 255).astype(np.uint8))
    keep = solid.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MaxFilter(7))
    a *= np.asarray(keep, dtype=np.float32) / 255
    # V's dark sleeve and belt are close to the backdrop colour, so the detected outline has
    # gaps there. Closing the mask (grow, then shrink, by about 20 px) seals them; it is
    # limited to that region so the crown spikes and hair keep their real edges.
    closed = solid
    for _ in range(20):
        closed = closed.filter(ImageFilter.MaxFilter(3))
    for _ in range(20):
        closed = closed.filter(ImageFilter.MinFilter(3))
    rx0, ry0, rx1, ry1 = (v - o for v, o in zip(box(*CLOSE_REGION), (x0, y0, x0, y0)))
    region = np.zeros((h, w), bool)
    region[max(0, ry0):ry1, max(0, rx0):rx1] = True
    sealed = (np.asarray(closed) > 127) & region
    # Pixels the backdrop cannot reach from the crop border are inside V (dark clothing,
    # the rifle). The bottom edge cuts V's legs, so it is not a backdrop border.
    bgmask = Image.fromarray((((a < 0.35) & ~sealed) * 255).astype(np.uint8))
    padded = Image.new("L", (w + 2, h + 2), 255)
    padded.paste(bgmask, (1, 1))
    ImageDraw.Draw(padded).line((0, h + 1, w + 1, h + 1), fill=0)
    ImageDraw.floodfill(padded, (0, 0), 128)
    outside = np.asarray(padded)[1:-1, 1:-1] == 128
    a[~outside] = np.maximum(a[~outside], 1.0)
    alpha = Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
    a = np.asarray(alpha, dtype=np.float32) / 255
    a[:60, :] *= np.linspace(0, 1, 60)[:, None]  # the rifle is cut by the crop's top edge
    fg = bg + (rgb - bg) / np.maximum(a, 0.08)[..., None]
    out = np.dstack([np.clip(fg, 0, 255), a * 255]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


# V: from just under the hub header to the screen bottom. "RYS…" of the POSES label
# overlaps her left edge.
V_BOX = (400, 118, 840, 1125)
CLOSE_REGION = (400, 380, 640, 1125)
matte(V_BOX, clear=[(392, 1060, 446, 1095)]).save(OUT / "v.png")
print("V box (display units)", V_BOX)


def icon(name, tile, inset, mode="tile"):
    x0, y0, x1, y1 = box(*tile)
    w, h = x1 - x0, y1 - y0
    l, t, r, b = inset
    crop = im.crop((x0 + round(w * l), y0 + round(h * t), x1 - round(w * r), y1 - round(h * b))).convert("RGBA")
    bg = im.getpixel((x0 + round(w * 0.5), y0 + round(h * 0.08)))
    px = crop.load()
    for y in range(crop.height):
        for x in range(crop.width):
            rr, gg, bb, _ = px[x, y]
            hh, ss, vv = colorsys.rgb_to_hsv(rr / 255, gg / 255, bb / 255)
            cyan = gg > 150 and bb > 150 and rr < 120
            if mode == "tile":
                d = abs(rr - bg[0]) + abs(gg - bg[1]) + abs(bb - bg[2])
                alpha = 0 if (d < 34 or cyan) else min(255, (d - 34) * 6)
            else:  # selected tile: dark teal circuit board behind the icon
                teal = 0.40 < hh < 0.58 and vv < 0.62
                alpha = 0 if (vv < 0.22 or teal or cyan) else 255
            px[x, y] = (rr, gg, bb, alpha)
    a = crop.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    crop.putalpha(a)
    bbox = crop.getbbox()
    if bbox:
        crop = crop.crop(bbox)
    crop.save(OUT / f"{name}.png")


# The 6 x 3 glasses grid. Each tile has a rarity strip on its left and a corner notch
# bottom right; the insets drop both.
for row in range(3):
    for col in range(6):
        x0 = 1193 + col * 116.6
        y0 = 731 + row * 105.3
        index = row * 6 + col
        name = "crown" if index == 0 else f"g{index:02d}"
        icon(name, (x0, y0, x0 + 112, y0 + 100), (0.14, 0.10, 0.06, 0.12),
             mode="circuit" if index == 0 else "tile")

for name in ("head", "face", "outer", "inner", "legs", "feet", "outfit", "world"):
    ext = ".jpg" if name == "world" else ".png"
    shutil.copy(INV / (name + ext), OUT / (name + ext))
print("assets written to", OUT)
