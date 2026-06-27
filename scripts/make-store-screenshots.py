"""Frame Quit Zyn screenshots into App Store marketing canvases.

Cream canvas + serif headline + sans subline + device-framed screenshot,
matching the Sober set's recipe. Erases the launch breadcrumb, normalizes the
status bar, rounds corners, adds a bezel + soft shadow.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SCRATCH = Path(__file__).resolve().parent / "screenshot-scratchpad"
OUT = ROOT / "fastlane/screenshots/en-US"
OUT.mkdir(parents=True, exist_ok=True)

CW, CH = 1320, 2868
CREAM = (246, 239, 224)
INK = (26, 26, 24)
WARMGRAY = (91, 86, 72)

SERIF = "/System/Library/Fonts/NewYork.ttf"
SANS = "/System/Library/Fonts/Helvetica.ttc"

# (source, headline, subline)
FRAMES = [
    ("cap_home2.png", "Count every\nnicotine-free day", "Your quit counter: days, streaks, and a tree that grows"),
    ("cap_bloom.png", "See what quitting\ngives back", "Money saved, pouches skipped, nicotine never absorbed"),
    ("cap_health.png", "Watch your\nbody recover", "13 nicotine-recovery milestones, with real sources"),
    ("cap_timeline.png", "Every clean day,\nat a glance", "A calendar of your streaks and progress"),
    ("cap_species.png", "Grow the tree\nyou choose", "Six bonsai species. Switch anytime, progress carries over"),
]


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0], size[1]], radius=radius, fill=255)
    return m


def prep_screenshot(path):
    shot = Image.open(path).convert("RGB")
    w, h = shot.size
    # Erase the "<- Quit Zyn" launch breadcrumb under the clock, keep 9:41.
    bg = shot.getpixel((40, 24))
    ImageDraw.Draw(shot).rectangle([16, 92, int(w * 0.34), 170], fill=bg)
    radius = 96
    shot.putalpha(rounded_mask((w, h), radius))
    return shot


def make_device(shot):
    pad = 20
    w, h = shot.size
    dev = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    body = Image.new("RGBA", dev.size, (8, 8, 10, 255))
    body.putalpha(rounded_mask(dev.size, 96 + pad))
    dev = Image.alpha_composite(dev, body)
    dev.alpha_composite(shot, (pad, pad))
    return dev


def font(path, size):
    return ImageFont.truetype(path, size)


def draw_centered(draw, lines, fnt, top, fill, leading):
    y = top
    for ln in lines:
        bb = draw.textbbox((0, 0), ln, font=fnt)
        w = bb[2] - bb[0]
        draw.text(((CW - w) / 2, y), ln, font=fnt, fill=fill)
        y += leading
    return y


def build(src, headline, subline, idx):
    src_path = SCRATCH / src
    if not src_path.exists():
        raise FileNotFoundError(f"Missing raw capture: {src_path}")

    canvas = Image.new("RGB", (CW, CH), CREAM)
    draw = ImageDraw.Draw(canvas)

    head_f = font(SERIF, 112)
    sub_size = 50
    sub_f = font(SANS, sub_size)
    max_w = 1170
    while draw.textlength(subline, font=sub_f) > max_w and sub_size > 38:
        sub_size -= 2
        sub_f = font(SANS, sub_size)

    hlines = headline.split("\n")
    y = draw_centered(draw, hlines, head_f, 170, INK, 132)
    draw_centered(draw, [subline], sub_f, y + 28, WARMGRAY, 64)

    shot = prep_screenshot(src_path)
    dev = make_device(shot)

    device_h = 2150
    scale = device_h / dev.size[1]
    dev = dev.resize((int(dev.size[0] * scale), device_h), Image.LANCZOS)
    dx = (CW - dev.size[0]) // 2
    dy = CH - device_h + 70

    shadow = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    sh = Image.new("RGBA", dev.size, (0, 0, 0, 0))
    sh.paste((0, 0, 0, 120), (0, 0), dev.split()[3])
    shadow.paste(sh, (dx, dy + 26), sh)
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    canvas.paste(Image.alpha_composite(canvas.convert("RGBA"), shadow).convert("RGB"), (0, 0))

    canvas.paste(dev, (dx, dy), dev)

    out = OUT / f"store-{idx}.png"
    canvas.save(out)
    print("wrote", out, canvas.size)


def main() -> int:
    missing = [src for src, _, _ in FRAMES if not (SCRATCH / src).exists()]
    if missing:
        print("error: copy raw captures into", SCRATCH, file=sys.stderr)
        for m in missing:
            print(f"  missing {m}", file=sys.stderr)
        return 1
    for i, (src, h, s) in enumerate(FRAMES, 1):
        build(src, h, s, i)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
