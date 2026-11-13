"""Compose 13-inch iPad App Store frames (2064x2752) from full-screen raw captures.

Usage: ipad_compose.py RAW_ROOT OUT_ROOT [locale ...]
RAW_ROOT/LOCALE/ipad/SCENE.png -> OUT_ROOT/LOCALE/FILE.png, headers from
../copy/headers.json, same frame order and headlines as the iPhone set.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

from common import LANCZOS, headline, read_json

HERE = Path(__file__).resolve().parent
KIT = HERE.parent
W, H = 2064, 2752
HEADER_BOX = (82, 120, 1900, 440)
BEZEL = (140, 650, 1784, 2000)  # outer x, y, w, h
BEZEL_THICK = 36
BEZEL_RADIUS = 150
FRAMES = [
    ("01-see-every-day-add-up.png", "home"),
    ("02-make-your-progress-personal.png", "garden"),
    ("03-notice-the-milestones-you-reach.png", "timeline"),
    ("04-see-what-staying-adds-up-to.png", "journal"),
    ("05-return-to-a-private-routine.png", "craving"),
    ("06-see-a-progress-milestone.png", "checkin"),
    ("07-see-the-cravings-you-rode-out.png", "patterns"),
]
TOP, BOTTOM = (237, 247, 236), (203, 226, 199)


def background() -> Image.Image:
    img = Image.new("RGB", (W, H))
    px = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        px.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return img


def rounded(size, radius, scale=4) -> Image.Image:
    mask = Image.new("L", (size[0] * scale, size[1] * scale), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] * scale - 1, size[1] * scale - 1), radius=radius * scale, fill=255)
    return mask.resize(size, LANCZOS)


def device(raw: Image.Image) -> Image.Image:
    x, y, w, h = BEZEL
    sw, sh = w - 2 * BEZEL_THICK, h - 2 * BEZEL_THICK
    crop_h = round(sh * raw.width / sw)
    screen = raw.convert("RGB").crop((0, 0, raw.width, min(crop_h, raw.height))).resize((sw, sh), LANCZOS)
    body = Image.new("RGB", (w, h), (12, 12, 12))
    body.paste(screen, (BEZEL_THICK, BEZEL_THICK), rounded((sw, sh), BEZEL_RADIUS - BEZEL_THICK))
    return body


def compose(locales: list[str], raw_root: Path, out_root: Path) -> None:
    headers = read_json(KIT / "copy" / "headers.json")
    base = background()
    for locale in locales:
        names = headers[locale]
        jobs = [{"text": names[file], "locale": locale, "font": "AvenirNextCondensed-Bold",
                 "color": [25, 53, 42], "box": list(HEADER_BOX[2:]), "maxSize": 210, "minSize": 110,
                 "align": "center", "out": str(out_root / ".h" / locale / f"{file}")} for file, _ in FRAMES]
        for job in jobs:
            Path(job["out"]).parent.mkdir(parents=True, exist_ok=True)
        results = headline(jobs)
        for (file, scene), job, res in zip(FRAMES, jobs, results):
            raw = Image.open(raw_root / locale / "ipad" / f"{scene}.png")
            canvas = base.copy()
            head = Image.open(job["out"]).convert("RGBA")
            canvas.paste(head, (HEADER_BOX[0], HEADER_BOX[1]), head)
            dev = device(raw)
            canvas.paste(dev, BEZEL[:2], rounded(dev.size, BEZEL_RADIUS))
            dest = out_root / locale / file
            dest.parent.mkdir(parents=True, exist_ok=True)
            canvas.save(dest, optimize=True)
            print(locale, file, res if isinstance(res, dict) else "", flush=True)


if __name__ == "__main__":
    raw_root, out_root = Path(sys.argv[1]), Path(sys.argv[2])
    locales = sys.argv[3:] or sorted(p.name for p in raw_root.iterdir() if p.is_dir())
    compose(locales, raw_root, out_root)
