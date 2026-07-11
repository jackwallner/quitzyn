#!/usr/bin/env python3
"""Upload IAP/subscription review screenshots, submit for review, equalize prices."""
from __future__ import annotations

import hashlib
import json
import mimetypes
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_api as a

APP = "6784788496"
REVIEW_IMAGE = Path(__file__).resolve().parent.parent / "fastlane/screenshots/en-US/store-1.png"
REVIEW_NOTES = (
    "Bloom+ unlocks the full health timeline, journal, achievements, savings stats, "
    "all garden species, and Apple Watch/widgets. Test via sandbox: open any locked Pro "
    "feature to reach the paywall. Restore Purchases works in Settings."
)


def upload_asset(path: Path, post_path: str, rel_type: str, rel_id: str, rel_key: str) -> str:
    data = path.read_bytes()
    size = len(data)
    body = {
        "data": {
            "type": post_path.rsplit("/", 1)[-1],
            "attributes": {"fileName": path.name, "fileSize": size},
            "relationships": {rel_key: {"data": {"type": rel_type, "id": rel_id}}},
        }
    }
    s, o = a.call("POST", post_path, body)
    if s not in (200, 201):
        raise RuntimeError(f"reserve {post_path} -> {s}: {o}")
    shot = o["data"]
    shot_id = shot["id"]
    ops = shot["attributes"].get("uploadOperations", [])
    if not ops:
        raise RuntimeError(f"no uploadOperations for {shot_id}: {o}")
    for op in ops:
        chunk = data[op.get("offset", 0) : op.get("offset", 0) + op.get("length", size)]
        req = urllib.request.Request(op["url"], data=chunk, method=op.get("method", "PUT"))
        for h in op.get("requestHeaders", []):
            req.add_header(h["name"], h["value"])
        with urllib.request.urlopen(req, timeout=120) as resp:
            resp.read()
    checksum = hashlib.md5(data).hexdigest()
    s, o = a.call(
        "PATCH",
        f"{post_path}/{shot_id}",
        {
            "data": {
                "type": post_path.rsplit("/", 1)[-1],
                "id": shot_id,
                "attributes": {"uploaded": True, "sourceFileChecksum": checksum},
            }
        },
    )
    if s != 200:
        raise RuntimeError(f"commit screenshot {shot_id} -> {s}: {o}")
    print(f"  uploaded review screenshot {shot_id} ({size} bytes)")
    return shot_id


def equalize_subscription_prices(sub_id: str, pid: str) -> None:
    s, o = a.call("GET", f"/v1/subscriptions/{sub_id}/prices?include=subscriptionPricePoint,territory&limit=5")
    prices = o.get("data", [])
    if not prices:
        print(f"  {pid}: no base price")
        return
    pp_id = prices[0]["relationships"]["subscriptionPricePoint"]["data"]["id"]
    s, o = a.call("GET", f"/v1/subscriptionPricePoints/{pp_id}/equalizations?limit=200")
    eq = o.get("data", [])
    print(f"  {pid}: equalizations {len(eq)}")
    ok = err = 0
    for point in eq:
        s, o = a.call(
            "POST",
            "/v1/subscriptionPrices",
            {
                "data": {
                    "type": "subscriptionPrices",
                    "attributes": {"startDate": None, "preserveCurrentPrice": False},
                    "relationships": {
                        "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                        "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": point["id"]}},
                    },
                }
            },
        )
        if s in (200, 201):
            ok += 1
        else:
            err += 1
    print(f"  {pid}: price rows created {ok} ok, {err} err (dupes expected)")


def main() -> int:
    if not REVIEW_IMAGE.exists():
        raise SystemExit(f"missing review image: {REVIEW_IMAGE}")

    s, o = a.call("GET", f"/v1/apps/{APP}/subscriptionGroups?limit=50")
    gid = next(g["id"] for g in o["data"] if g["attributes"].get("referenceName") == "Bloom+")
    s, o = a.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptions?limit=50")
    subs = o["data"]

    for sub in subs:
        sid = sub["id"]
        pid = sub["attributes"]["productId"]
        print(f"\n== {pid} ==")
        equalize_subscription_prices(sid, pid)
        shot_id = upload_asset(
            REVIEW_IMAGE,
            "/v1/subscriptionAppStoreReviewScreenshots",
            "subscriptions",
            sid,
            "subscription",
        )
        s, o = a.call(
            "POST",
            "/v1/subscriptionAppStoreReviewSubmissions",
            {
                "data": {
                    "type": "subscriptionAppStoreReviewSubmissions",
                    "attributes": {"reviewerNotes": REVIEW_NOTES[:4000]},
                    "relationships": {
                        "subscription": {"data": {"type": "subscriptions", "id": sid}},
                        "appStoreReviewScreenshot": {
                            "data": {"type": "subscriptionAppStoreReviewScreenshots", "id": shot_id}
                        },
                    },
                }
            },
        )
        print(f"  review submission -> {s}" + ("" if s in (200, 201) else f" {json.dumps(o.get('errors', o))[:300]}"))

    s, o = a.call(
        "GET",
        f"/v1/apps/{APP}/inAppPurchasesV2?filter[productId]=com.jackwallner.quitzyn.pro.lifetime&limit=5",
    )
    iid = o["data"][0]["id"]
    print(f"\n== lifetime ==")
    shot_id = upload_asset(
        REVIEW_IMAGE,
        "/v1/inAppPurchaseAppStoreReviewScreenshots",
        "inAppPurchases",
        iid,
        "inAppPurchaseV2",
    )
    s, o = a.call(
        "POST",
        "/v1/inAppPurchaseAppStoreReviewSubmissions",
        {
            "data": {
                "type": "inAppPurchaseAppStoreReviewSubmissions",
                "attributes": {"reviewerNotes": REVIEW_NOTES[:4000]},
                "relationships": {
                    "inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}},
                    "appStoreReviewScreenshot": {
                        "data": {"type": "inAppPurchaseAppStoreReviewScreenshots", "id": shot_id}
                    },
                },
            }
        },
    )
    print(f"  lifetime review submission -> {s}" + ("" if s in (200, 201) else f" {json.dumps(o.get('errors', o))[:300]}"))

    print("\n== final states ==")
    s, o = a.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptions?limit=50")
    for sub in o["data"]:
        print(f"  {sub['attributes']['productId']}: {sub['attributes']['state']}")
    s, o = a.call(
        "GET",
        f"/v1/apps/{APP}/inAppPurchasesV2?filter[productId]=com.jackwallner.quitzyn.pro.lifetime&limit=5",
    )
    print(f"  lifetime: {o['data'][0]['attributes']['state']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
