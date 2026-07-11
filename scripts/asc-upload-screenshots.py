#!/usr/bin/env python3
"""Upload App Store screenshots to every locale on draft version via ASC API."""
from __future__ import annotations

import hashlib
import json
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib as L

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "fastlane/screenshots"
IPHONE_DIR = "iPhone 6.7 Display"
WATCH_DIR = "Apple Watch Series 10 (46mm)"
DISPLAY = {
    IPHONE_DIR: "APP_IPHONE_67",
    WATCH_DIR: "APP_WATCH_SERIES_10",
}


def upload_screenshot(client: L.ASCClient, set_id: str, path: Path) -> None:
    data = path.read_bytes()
    size = len(data)
    reserved = client.post(
        "/appScreenshots",
        {
            "data": {
                "type": "appScreenshots",
                "attributes": {"fileName": path.name, "fileSize": size},
                "relationships": {
                    "appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}
                },
            }
        },
    )["data"]
    shot_id = reserved["id"]
    for op in reserved["attributes"].get("uploadOperations", []):
        chunk = data[op.get("offset", 0) : op.get("offset", 0) + op.get("length", size)]
        req = urllib.request.Request(op["url"], data=chunk, method=op.get("method", "PUT"))
        for h in op.get("requestHeaders", []):
            req.add_header(h["name"], h["value"])
        with urllib.request.urlopen(req, timeout=180) as resp:
            resp.read()
    client.patch(
        f"/appScreenshots/{shot_id}",
        {
            "data": {
                "type": "appScreenshots",
                "id": shot_id,
                "attributes": {
                    "uploaded": True,
                    "sourceFileChecksum": hashlib.md5(data).hexdigest(),
                },
            }
        },
    )


def ensure_set(client: L.ASCClient, loc_id: str, display: str, existing: dict[str, str]) -> str:
    if display in existing:
        return existing[display]
    created = client.post(
        "/appScreenshotSets",
        {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display},
                "relationships": {
                    "appStoreVersionLocalization": {
                        "data": {"type": "appStoreVersionLocalizations", "id": loc_id}
                    }
                },
            }
        },
    )["data"]
    return created["id"]


def main() -> int:
    version = __import__("os").environ.get("ASC_APP_VERSION", "1.0")
    kid, iss, kp = L.load_credentials()
    client = L.ASCClient(L.bearer_token(kid, iss, kp))
    app = L.find_app(client, L.bundle_id_from_appfile())
    ver = L.find_version_by_string(client, app["id"], version)
    if not ver:
        raise SystemExit(f"version {version} not found")
    ver_id = ver["id"]
    locs = {
        x["attributes"]["locale"]: x
        for x in L.list_all(client, f"/appStoreVersions/{ver_id}/appStoreVersionLocalizations")
    }
    locales = L.fastlane_locale_dirs()
    ok = fail = 0
    for locale in locales:
        if locale not in locs:
            print(f"{locale}: skip (no version localization)")
            fail += 1
            continue
        loc_id = locs[locale]["id"]
        src = SHOTS / locale
        if not src.exists():
            print(f"{locale}: skip (no screenshot dir)")
            fail += 1
            continue
        sets = {
            s["attributes"]["screenshotDisplayType"]: s["id"]
            for s in L.list_all(client, f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")
        }
        # clear existing screenshots in each set
        for sid in list(sets.values()):
            for shot in L.list_all(client, f"/appScreenshotSets/{sid}/appScreenshots"):
                try:
                    client.request("DELETE", f"/appScreenshots/{shot['id']}")
                except Exception:
                    pass
        uploaded = 0
        try:
            for folder, display in DISPLAY.items():
                files = sorted((src / folder).glob("*.png"))
                if not files:
                    continue
                set_id = ensure_set(client, loc_id, display, sets)
                for f in files:
                    upload_screenshot(client, set_id, f)
                    uploaded += 1
                    time.sleep(0.15)
            print(f"{locale}: ok ({uploaded} images)")
            ok += 1
        except Exception as e:
            print(f"{locale}: fail {e}")
            fail += 1
        time.sleep(0.25)
    print(f"\nDone: {ok}/{len(locales)} locales ok, {fail} failed")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
