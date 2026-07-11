#!/usr/bin/env python3
"""Copy en-US marketing screenshots into every ASC locale folder for fastlane deliver."""
from __future__ import annotations

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "fastlane/screenshots"
SRC = SHOTS / "en-US"
LOCALES = json.loads((Path(__file__).parent / "asc-supported-locales.json").read_text())["locales"]

# fastlane deliver device folder names (ASC display types)
IPHONE_DIR = "iPhone 6.7 Display"
WATCH_DIR = "Apple Watch Series 10 (46mm)"

IPHONE_FILES = sorted(SRC.glob("store-*.png"))
WATCH_FILES = sorted(SRC.glob("*watch*.png"))


def main() -> None:
    if not IPHONE_FILES:
        raise SystemExit(f"no iPhone screenshots in {SRC}")
    for loc in LOCALES:
        dest = SHOTS / loc
        iphone_dest = dest / IPHONE_DIR
        watch_dest = dest / WATCH_DIR
        iphone_dest.mkdir(parents=True, exist_ok=True)
        watch_dest.mkdir(parents=True, exist_ok=True)
        for i, src in enumerate(IPHONE_FILES, 1):
            shutil.copy2(src, iphone_dest / f"{i:02d}_{src.name}")
        for i, src in enumerate(WATCH_FILES, 1):
            shutil.copy2(src, watch_dest / f"{i:02d}_{src.name}")
    print(f"Prepared screenshots for {len(LOCALES)} locales")
    print(f"  iPhone: {len(IPHONE_FILES)} -> {IPHONE_DIR}")
    print(f"  Watch: {len(WATCH_FILES)} -> {WATCH_DIR}")


if __name__ == "__main__":
    main()
