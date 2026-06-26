"""Frame Quit Zyn screenshots into App Store marketing canvases.

Cream canvas + serif headline + sans subline + device-framed screenshot,
matching the Sober set's recipe. Erases the launch breadcrumb, normalizes the
status bar, rounds corners, adds a bezel + soft shadow.
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SCRATCH = "/private/tmp/claude-501/-Users-jackwallner-nicfree/e931b6ce-54ba-4b65-8f01-729a0ab3f62e/scratchpad"
OUT = os.path.join(SCRATCH, "store")
os.makedirs(OUT, exist_ok=True)

CW, CH = 1320, 2868
CREAM = (246, 239, 224)
INK = (26, 26, 24)
WARMGRAY = (91, 86, 72)

SERIF = "/System/Library/Fonts/NewYork.ttf"
SANS = "/System/Library/Fonts/Helvetica.ttc"

# (source, headline, subline)
FRAMES = [
    ("cap_home2.png",  "Count every\nnicotine-free day",
     "Your quit counter — days, streaks, and a tree that grows"),
    ("cap_bloom.png",  "See what quitting\ngives back",
     "Money saved, pouches skipped, nicotine never absorbed"),
    ("cap_health.png", "Watch your\nbody recover",
     "13 nicotine-recovery milestones, with real sources"),
    ("cap_timeline.png", "Every clean day,\nat a glance",
     "A calendar of your streaks and progress"),
    ("cap_species.png", "Grow the tree\nyou choose",
     "Six bonsai species — switch anytime, progress carries over"),
]


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0], size[1]], radius=radius, fill=255)
    return m


def prep_screenshot(path):
    shot = Image.open(path).convert("RGB")
    w, h = shot.size
    # Erase the "<- Sober Tracker" launch breadcrumb under the clock, keep 9:41.
    bg = shot.getpixel((40, 24))
    ImageDraw.Draw(shot).rectangle([16, 92, int(w * 0.34), 170], fill=bg)
    # Round the corners.
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
    canvas = Image.new("RGB", (CW, CH), CREAM)
    draw = ImageDraw.Draw(canvas)

    head_f = font(SERIF, 112)
    # Auto-fit the subline so the longest one never crowds the safe margins.
    sub_size = 50
    sub_f = font(SANS, sub_size)
    max_w = 1170
    while draw.textlength(subline, font=sub_f) > max_w and sub_size > 38:
        sub_size -= 2
        sub_f = font(SANS, sub_size)

    hlines = headline.split("\n")
    y = draw_centered(draw, hlines, head_f, 170, INK, 132)
    # subline a bit below headline
    draw_centered(draw, [subline], sub_f, y + 28, WARMGRAY, 64)

    shot = prep_screenshot(os.path.join(SCRATCH, src))
    dev = make_device(shot)

    DEVICE_H = 2150
    scale = DEVICE_H / dev.size[1]
    dev = dev.resize((int(dev.size[0] * scale), DEVICE_H), Image.LANCZOS)
    dx = (CW - dev.size[0]) // 2
    dy = CH - DEVICE_H + 70  # bleed slightly off the bottom

    # soft shadow
    shadow = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    sh = Image.new("RGBA", dev.size, (0, 0, 0, 0))
    sh.paste((0, 0, 0, 120), (0, 0), dev.split()[3])
    shadow.paste(sh, (dx, dy + 26), sh)
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    canvas.paste(Image.alpha_composite(canvas.convert("RGBA"), shadow).convert("RGB"), (0, 0))

    canvas.paste(dev, (dx, dy), dev)

    out = os.path.join(OUT, f"store-{idx}.png")
    canvas.save(out)
    print("wrote", out, canvas.size)


for i, (src, h, s) in enumerate(FRAMES, 1):
    build(src, h, s, i)
