#!/usr/bin/env python3
"""PROTOTYPE asset cutter: crops V and item icons from one in-game screenshot.

Usage: python3 prototype/inventory-mockups/build_assets.py [screenshot.jpg]
Coordinates below are in the 2000x1125 display space of the screenshot; S maps
them to its native 2560x1440 pixels.
"""
import colorsys
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SRC = Path(sys.argv[1] if len(sys.argv) > 1 else
           Path.home() / ".local/share/Steam/userdata/82605613/760/remote/1091500/screenshots/20261014163249_1.jpg")
OUT = Path(__file__).resolve().parent / "assets"
S = 1.28

im = Image.open(SRC).convert("RGB")
OUT.mkdir(exist_ok=True)
im.save(OUT / "current.jpg", quality=90)


def box(x0, y0, x1, y1):
    return tuple(round(v * S) for v in (x0, y0, x1, y1))


def feather(img, left, top, right, bottom):
    """Alpha mask that fades each edge over the given number of pixels."""
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rectangle((left, top, w - right, h - bottom), fill=255)
    radius = max(left, top, right, bottom) / 2
    mask = mask.filter(ImageFilter.GaussianBlur(radius))
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def matte(v):
    """Cut V off the menu backdrop so the backdrop can be made transparent.

    The backdrop is a smooth gradient: fit a quartic surface to empty screen areas,
    key V against it, fill small holes inside her outline, and unmix edge colours.
    """
    import numpy as np
    full = np.asarray(im, dtype=np.float32)
    rects = [(662, 135, 790, 400), (1050, 135, 1300, 420), (1160, 430, 1300, 815), (662, 770, 705, 1050),
             (1100, 985, 1280, 1050), (50, 200, 290, 1000), (1600, 150, 1925, 1040), (300, 135, 650, 190),
             (1000, 128, 1300, 190), (580, 480, 615, 560)]
    terms = [(i, j) for i in range(5) for j in range(5 - i)]

    def design(xs, ys):
        return np.stack([(xs / 2560) ** i * (ys / 1440) ** j for i, j in terms], axis=-1)

    xs, ys = [], []
    for r in rects:
        x0, y0, x1, y1 = box(*r)
        gy, gx = np.mgrid[y0:y1:4, x0:x1:4]
        xs.append(gx.ravel()); ys.append(gy.ravel())
    xs = np.concatenate(xs).astype(np.float32); ys = np.concatenate(ys).astype(np.float32)
    samples = full[ys.astype(int), xs.astype(int)]
    coef, *_ = np.linalg.lstsq(design(xs, ys), samples, rcond=None)
    rms = np.sqrt(np.mean((design(xs, ys) @ coef - samples) ** 2))
    print("backdrop fit rms", round(float(rms), 2))

    cx0, cy0 = box(662, 124, 662, 124)[:2]
    rgb = np.asarray(v, dtype=np.float32)
    h, w = rgb.shape[:2]
    gy, gx = np.mgrid[0:h, 0:w]
    bg = (design((gx + cx0).astype(np.float32), (gy + cy0).astype(np.float32)) @ coef).reshape(h, w, 3)
    d = np.sqrt(((rgb - bg) ** 2).sum(-1))
    a = np.clip((d - 10) / 26, 0, 1)
    # A low threshold keeps dark clothing but lets JPEG noise through; opening the
    # mask removes isolated specks, and a dilated copy keeps soft edges intact.
    solid = Image.fromarray(((a > 0.35) * 255).astype(np.uint8))
    keep = solid.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MaxFilter(7))
    a *= np.asarray(keep, dtype=np.float32) / 255

    # Anything the backdrop cannot reach from the image border is inside V: dark
    # clothing and the gun match the backdrop colour but must stay opaque.
    bgmask = Image.fromarray(((a < 0.35) * 255).astype(np.uint8))
    padded = Image.new("L", (w + 2, h + 2), 255)
    padded.paste(bgmask, (1, 1))
    # The screen edge cuts V's legs, so the bottom border is not backdrop.
    ImageDraw.Draw(padded).line((0, h + 1, w + 1, h + 1), fill=0)
    ImageDraw.floodfill(padded, (0, 0), 128)
    outside = np.asarray(padded)[1:-1, 1:-1] == 128
    a[~outside] = np.maximum(a[~outside], 1.0)

    alpha = Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
    a = np.asarray(alpha, dtype=np.float32) / 255
    a[:, :50] *= np.linspace(0, 1, 50)[None, :]  # the gun is cut by the crop's left edge
    fg = bg + (rgb - bg) / np.maximum(a, 0.08)[..., None]
    out = np.dstack([np.clip(fg, 0, 255), a * 255]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


# V: x from 662 clears the cyberware tile drawn over the gun; paint out the V key hint.
v = im.crop(box(662, 124, 1306, 1125))
hint = tuple(round(c - o) for c, o in zip(box(1282, 1060, 1306, 1110), (box(662, 124, 662, 124) * 2)[:4]))
patch = v.crop((hint[0], hint[1] - 70, hint[2], hint[1] - 70 + (hint[3] - hint[1])))
v.paste(patch, hint[:2])
# Paint out the game's mouse cursor (cyan hand on the gun) by diffusing neighbours inward.
cb = tuple(round(c * S) for c in (800 - 662, 628 - 124, 840 - 662, 672 - 124))
px = v.load()
hole = {(x, y) for x in range(cb[0], cb[2]) for y in range(cb[1], cb[3])
        if (lambda r, g, b: (g - r > 25 and b - r > 25) or r + g + b > 560)(*px[x, y])}
hole |= {(x + dx, y + dy) for x, y in list(hole) for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0, 1, 2)}
while hole:
    filled = {}
    for x, y in hole:
        n = [px[x + dx, y + dy] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if (x + dx, y + dy) not in hole]
        if n:
            filled[(x, y)] = tuple(sum(c[i] for c in n) // len(n) for i in range(3))
    for k, c in filled.items():
        px[k] = c
    hole -= set(filled)
matte(v).save(OUT / "v.png")

# Background tones sampled from empty screen areas, for the page gradient.
for name, xy in {"top": (180, 160), "upper": (180, 420), "lower": (180, 760), "bottom": (180, 1080),
                 "mid_top": (1000, 135)}.items():
    print(name, "#%02x%02x%02x" % im.getpixel(tuple(round(c * S) for c in xy)))


def key_icon(name, tile, inset=(0.06, 0.06, 0.06, 0.06), mode="tile"):
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
            else:  # cyberware circuit art: dark teal board and lighter teal traces
                teal = 0.40 < hh < 0.58 and vv < 0.55
                alpha = 0 if (vv < 0.20 or teal or cyan) else 255
            # The status dot's glow sits in the top-right corner of every tile.
            if x > crop.width * 0.72 and y < crop.height * 0.40:
                alpha = 0
            px[x, y] = (rr, gg, bb, alpha)
    if mode != "tile":
        # Opening (erode then dilate) removes isolated circuit-trace speckles.
        a = crop.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
        crop.putalpha(a)
    bbox = crop.getbbox()
    if bbox:
        crop = crop.crop(bbox)
    crop.save(OUT / f"{name}.png")


# Insets drop the cyan dot (top right), corner triangle (bottom right) and badges (bottom left).
key_icon("w1", (313, 232, 428, 340), (0.08, 0.12, 0.08, 0.30))
key_icon("w2", (440, 232, 555, 340), (0.08, 0.12, 0.08, 0.30))
key_icon("w3", (313, 352, 555, 462), (0.08, 0.12, 0.08, 0.30))
for name, tile in {"head": (1323, 232, 1437, 325), "face": (1323, 330, 1437, 422),
                   "outer": (1453, 232, 1566, 325), "inner": (1453, 330, 1566, 422),
                   "legs": (1323, 483, 1437, 575), "feet": (1323, 580, 1437, 672),
                   "outfit": (1453, 483, 1566, 672)}.items():
    key_icon(name, tile, (0.10, 0.10, 0.12, 0.20))
key_icon("q1", (313, 758, 427, 874), (0.10, 0.10, 0.12, 0.22))
key_icon("q2", (432, 758, 546, 874), (0.18, 0.10, 0.12, 0.22))
key_icon("cy1", (313, 573, 428, 676), (0.14, 0.06, 0.06, 0.06), mode="circuit")
key_icon("cy2", (430, 573, 545, 676), (0.14, 0.06, 0.06, 0.06), mode="circuit")
key_icon("cy3", (547, 573, 660, 676), (0.14, 0.06, 0.06, 0.06), mode="circuit")
# Stand-in game scene for the transparent-backdrop test: the right part of a street
# screenshot (no people), mirrored so its seam sits behind V at screen centre.
WORLD = Path.home() / ".local/share/Steam/userdata/82605613/760/remote/1091500/screenshots/20260902224534_1.jpg"
street = Image.open(WORLD).convert("RGB")
right = street.crop((1120, 0, street.width, street.height))
world = Image.new("RGB", (right.width * 2, right.height))
world.paste(right.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (0, 0))
world.paste(right, (right.width, 0))
world.save(OUT / "world.jpg", quality=88)
print("assets written to", OUT)
