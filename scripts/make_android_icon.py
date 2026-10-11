#!/usr/bin/env python3
"""Android launcher icon from the iOS app icon (no redrawing, so they never drift).

The iOS icon is a crossed-out pouch on a dark gradient square. The adaptive
icon's foreground is that whole square, mapped onto the 72dp visible area of
the 108dp canvas (the glyph stays inside the 66dp safe zone), over a background
of the square's own edge colour. A white silhouette of the glyph, keyed off the
dark field, serves as the themed-icon monochrome layer. Also writes the 512px
Play icon.
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Sober/Assets.xcassets/AppIcon.appiconset/icon_1024.png"
RES = ROOT / "android/app/src/main/res"
DENSITIES = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def silhouette(icon: Image.Image) -> Image.Image:
    """White glyph with the dark field keyed out. Where the red slash crosses the
    white pouch, a gap is cut around the slash so it still reads in one colour."""
    bg = icon.getpixel((8, 8))
    red = Image.new("L", icon.size)
    pouch = Image.new("L", icon.size)
    src, red_px, pouch_px = icon.load(), red.load(), pouch.load()
    for y in range(icon.height):
        for x in range(icon.width):
            r, g, b = src[x, y]
            distance = max(abs(r - bg[0]), abs(g - bg[1]), abs(b - bg[2]))
            alpha = max(0, min(255, (distance - 40) * 3))
            if r - max(g, b) > 60:
                red_px[x, y] = alpha
            else:
                pouch_px[x, y] = alpha
    gap = red.point(lambda v: 255 if v > 128 else 0).filter(ImageFilter.MaxFilter(41))
    pouch = ImageChops.subtract(pouch, gap)
    out = Image.new("RGBA", icon.size, (255, 255, 255, 0))
    out.putalpha(ImageChops.lighter(red, pouch))
    return out


def layer(art: Image.Image, px: int) -> Image.Image:
    canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    inner = round(px * 72 / 108)
    canvas.paste(art.resize((inner, inner), Image.LANCZOS), ((px - inner) // 2, (px - inner) // 2))
    return canvas


def main() -> None:
    icon = Image.open(SOURCE).convert("RGB")
    bg = icon.getpixel((8, 8))
    color, white = icon.convert("RGBA"), silhouette(icon)
    for name, px in DENSITIES.items():
        folder = RES / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        layer(color, px).save(folder / "ic_launcher_foreground.png")
        layer(white, px).save(folder / "ic_launcher_monochrome.png")
        for stale in folder.glob("ic_launcher_background.png"):
            stale.unlink()
    values = RES / "values"
    (values / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <color name="ic_launcher_background">#{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}</color>\n</resources>\n'
    )
    xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
"""
    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(xml)
    (anydpi / "ic_launcher_round.xml").write_text(xml)
    assets = ROOT / "android/play-assets"
    assets.mkdir(parents=True, exist_ok=True)
    icon.resize((512, 512), Image.LANCZOS).save(assets / "icon-512.png")
    print("wrote adaptive icon layers and play-assets/icon-512.png")


if __name__ == "__main__":
    main()
