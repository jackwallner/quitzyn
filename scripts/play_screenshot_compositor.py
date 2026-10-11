#!/usr/bin/env python3
"""Composite raw Android captures into Google Play screenshots and the feature graphic.

Same look and copy as the App Store set (fastlane/screenshots/en-US): one large
two-line headline over a soft green wash, with the real capture in a rounded
phone frame below. Play rejects anything longer than 2:1, so frames are
1080x1920. Reads android/play-assets/raw/ (1080x2400 captures from the debug
build) and writes android/play-assets/screenshots/ and
android/play-assets/feature-graphic.png.

Usage: python3 scripts/play_screenshot_compositor.py
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "android" / "play-assets"
RAW = ASSETS / "raw"
OUT = ASSETS / "screenshots"
FONTS = ROOT / "android" / "app" / "src" / "main" / "res" / "font"

W, H = 1080, 1920
WASH_TOP = (237, 247, 236)
WASH_BOTTOM = (203, 226, 199)
INK = (22, 28, 24)
BEZEL = (24, 26, 30)
FIELD_TOP = (31, 35, 42)
FIELD_BOTTOM = (21, 24, 30)
CREAM_TEXT = (240, 236, 228)


@dataclass
class Shot:
    raw: str
    headline: tuple[str, str]


SHOTS = [
    Shot("01-home.png", ("See each", "nicotine-free day")),
    Shot("02-species.png", ("Make your", "progress personal")),
    Shot("03-timeline.png", ("Review the days", "behind your count")),
    Shot("04-journal.png", ("Return to a", "nicotine-free routine")),
    Shot("05-craving.png", ("Keep a private", "progress ritual")),
    Shot("06-checkin.png", ("See a progress", "milestone")),
    Shot("07-patterns.png", ("See the cravings", "you rode out")),
]


def font(name: str, size: int, weight: int, opsz: int | None = None) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONTS / name), size)
    axes = {"Weight": weight}
    if opsz:
        axes["Optical size"] = opsz
    try:
        names = [a.decode() if isinstance(a, bytes) else a for a in f.get_variation_axes()]
        f.set_variation_by_axes([axes.get(a["name"].decode() if isinstance(a["name"], bytes) else a["name"], a["default"]) for a in f.get_variation_axes()])
    except Exception:
        pass
    return f


def gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGB", size, top)
    d = ImageDraw.Draw(img)
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        d.line([(0, y), (size[0], y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img


def render(shot: Shot) -> Path:
    img = gradient((W, H), WASH_TOP, WASH_BOTTOM)
    d = ImageDraw.Draw(img)
    head = font("nunito.ttf", 84, 600)
    for i, line in enumerate(shot.headline):
        width = d.textlength(line, font=head)
        d.text(((W - width) / 2, 92 + i * 100), line, font=head, fill=INK)

    raw = Image.open(RAW / shot.raw).convert("RGB")
    if raw.size != (1080, 2400):
        raise ValueError(f"{shot.raw} is {raw.size}, expected 1080x2400")
    top, bezel, radius = 330, 16, 36
    sh = H - top + 140
    sw = round(sh * raw.width / raw.height)
    screen = raw.resize((sw, sh), Image.LANCZOS)
    left = (W - sw) // 2
    frame_box = [(left - bezel, top - bezel), (left + sw + bezel, top + sh + bezel)]
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([(x, y + 18) for x, y in frame_box], radius=radius + bezel, fill=(20, 40, 24, 70))
    img.paste(shadow.filter(ImageFilter.GaussianBlur(26)), (0, 0), shadow.filter(ImageFilter.GaussianBlur(26)))
    ImageDraw.Draw(img).rounded_rectangle(frame_box, radius=radius + bezel, fill=BEZEL)
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([(0, 0), (sw - 1, sh - 1)], radius=radius, fill=255)
    img.paste(screen, (left, top), mask)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / shot.raw.replace(".png", ".jpg")
    img.save(path, "JPEG", quality=92)
    return path


def feature_graphic() -> Path:
    fw, fh = 1024, 500
    img = gradient((fw, fh), FIELD_TOP, FIELD_BOTTOM)
    d = ImageDraw.Draw(img)
    icon = Image.open(ROOT / "Sober/Assets.xcassets/AppIcon.appiconset/icon_1024.png").convert("RGB").resize((150, 150), Image.LANCZOS)
    m = Image.new("L", (150, 150), 0)
    ImageDraw.Draw(m).rounded_rectangle([(0, 0), (149, 149)], radius=34, fill=255)
    img.paste(icon, (70, 80), m)
    d.text((70, 250), "Quit Zyn", font=font("newsreader.ttf", 84, 500, 72), fill=CREAM_TEXT)
    tagline = font("nunito.ttf", 32, 500)
    d.text((72, 352), "Count nicotine-free days.", font=tagline, fill=(196, 202, 208))
    d.text((72, 394), "Grow a bonsai as you go.", font=tagline, fill=(196, 202, 208))
    tree = Image.open(RAW / "01-home.png").convert("RGB").crop((40, 500, 1040, 1640))
    tree = tree.resize((round(tree.width * 420 / tree.height), 420), Image.LANCZOS)
    tm = Image.new("L", tree.size, 0)
    ImageDraw.Draw(tm).rounded_rectangle([(0, 0), (tree.width - 1, tree.height - 1)], radius=30, fill=255)
    img.paste(tree, (fw - tree.width - 60, (fh - tree.height) // 2), tm)
    path = ASSETS / "feature-graphic.png"
    img.save(path, "PNG")
    return path


def main() -> None:
    for shot in SHOTS:
        print(render(shot))
    print(feature_graphic())


if __name__ == "__main__":
    main()
