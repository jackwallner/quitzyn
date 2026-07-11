#!/usr/bin/env python3
"""Complete Bloom+ IAP metadata on ASC: descriptions, availability, pricing, trial."""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_api as a

APP = "6784788496"
GROUP_REF = "Bloom+"

SUB_DESC = {
    "com.jackwallner.quitzyn.pro.monthly": (
        "Full health timeline, journal, stats & garden"
    ),
    "com.jackwallner.quitzyn.pro.yearly": (
        "All Pro features; free trial may be offered"
    ),
}
LIFETIME_DESC = "Lifetime Pro: timeline, journal & garden"
LIFETIME = {"productId": "com.jackwallner.quitzyn.pro.lifetime", "name": "Bloom+ Lifetime", "price": "59.99"}
PRICES = {"com.jackwallner.quitzyn.pro.monthly": "4.99", "com.jackwallner.quitzyn.pro.yearly": "29.99"}
TRIAL_PRODUCT = "com.jackwallner.quitzyn.pro.yearly"


def ok_post(path: str, body: dict) -> tuple[int, dict, bool]:
    s, o = a.call("POST", path, body)
    return s, o, s in (200, 201)


def ok_patch(path: str, body: dict) -> tuple[int, dict, bool]:
    s, o = a.call("PATCH", path, body)
    return s, o, s in (200, 201)


def closest_price_point(points: list, target: str) -> str | None:
    tf = float(target)
    best, bestd = None, 1e9
    for p in points:
        cp = p["attributes"].get("customerPrice")
        if cp is None:
            continue
        d = abs(float(cp) - tf)
        if d < bestd:
            best, bestd = p, d
    return best["id"] if best else None


def main() -> int:
    # subscription group + subs
    s, o = a.call("GET", f"/v1/apps/{APP}/subscriptionGroups?limit=50")
    group = next(g for g in o["data"] if g["attributes"].get("referenceName") == GROUP_REF)
    gid = group["id"]
    s, o = a.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptions?limit=50")
    subs = {x["attributes"]["productId"]: x for x in o["data"]}

    # territories
    s, o = a.call("GET", "/v1/territories?limit=200")
    terrs = [t["id"] for t in o["data"]]
    terr_data = [{"type": "territories", "id": t} for t in terrs]
    print(f"territories: {len(terrs)}")

    for pid, sub in subs.items():
        sid = sub["id"]
        state = sub["attributes"].get("state")
        print(f"\n== {pid} (state={state}) ==")

        # availability
        s, o, ok = ok_post(
            "/v1/subscriptionAvailabilities",
            {
                "data": {
                    "type": "subscriptionAvailabilities",
                    "attributes": {"availableInNewTerritories": True},
                    "relationships": {
                        "subscription": {"data": {"type": "subscriptions", "id": sid}},
                        "availableTerritories": {"data": terr_data},
                    },
                }
            },
        )
        print(f"  availability -> {s}" + ("" if ok else f" {json.dumps(o.get('errors', o))[:180]}"))

        # price
        price = PRICES[pid]
        s, o = a.call("GET", f"/v1/subscriptions/{sid}/pricePoints?filter[territory]=USA&limit=400")
        pp = closest_price_point(o.get("data", []), price)
        if pp:
            s, o, ok = ok_post(
                "/v1/subscriptionPrices",
                {
                    "data": {
                        "type": "subscriptionPrices",
                        "attributes": {"startDate": None, "preserveCurrentPrice": False},
                        "relationships": {
                            "subscription": {"data": {"type": "subscriptions", "id": sid}},
                            "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": pp}},
                        },
                    }
                },
            )
            print(f"  price ${price} -> {s}" + ("" if ok else f" {json.dumps(o.get('errors', o))[:180]}"))

        # localization description
        s, o = a.call("GET", f"/v1/subscriptions/{sid}/subscriptionLocalizations?limit=20")
        for loc in o.get("data", []):
            lid = loc["id"]
            locale = loc["attributes"].get("locale")
            desc = SUB_DESC.get(pid, "")
            if not desc:
                continue
            s, o, ok = ok_patch(
                f"/v1/subscriptionLocalizations/{lid}",
                {
                    "data": {
                        "type": "subscriptionLocalizations",
                        "id": lid,
                        "attributes": {"description": desc[:45]},
                    }
                },
            )
            print(f"  desc {locale} ({len(desc)} chars) -> {s}" + ("" if ok else f" {json.dumps(o.get('errors', o))[:180]}"))

    # yearly free trial (all territories)
    sid = subs[TRIAL_PRODUCT]["id"]
    ok_n = err_n = 0
    for t in terrs:
        s, o, ok = ok_post(
            "/v1/subscriptionIntroductoryOffers",
            {
                "data": {
                    "type": "subscriptionIntroductoryOffers",
                    "attributes": {"duration": "ONE_WEEK", "numberOfPeriods": 1, "offerMode": "FREE_TRIAL"},
                    "relationships": {
                        "subscription": {"data": {"type": "subscriptions", "id": sid}},
                        "territory": {"data": {"type": "territories", "id": t}},
                    },
                }
            },
        )
        if ok:
            ok_n += 1
        else:
            err_n += 1
    print(f"\nfree trial: {ok_n} ok, {err_n} err (dupes expected if already set)")

    # lifetime non-consumable
    print(f"\n== {LIFETIME['productId']} ==")
    s, o = a.call("GET", f"/v1/apps/{APP}/inAppPurchasesV2?filter[productId]={LIFETIME['productId']}&limit=5")
    iap = o["data"][0]
    iid = iap["id"]
    print(f"  state={iap['attributes'].get('state')}")

    s, o, ok = ok_post(
        "/v1/inAppPurchaseAvailabilities",
        {
            "data": {
                "type": "inAppPurchaseAvailabilities",
                "attributes": {"availableInNewTerritories": True},
                "relationships": {
                    "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                    "availableTerritories": {"data": terr_data},
                },
            }
        },
    )
    print(f"  availability -> {s}" + ("" if ok else f" {json.dumps(o.get('errors', o))[:180]}"))

    # localization — try create then patch
    loc_id = None
    s, o, ok = ok_post(
        "/v1/inAppPurchaseLocalizations",
        {
            "data": {
                "type": "inAppPurchaseLocalizations",
                "attributes": {
                    "name": LIFETIME["name"],
                    "locale": "en-US",
                    "description": LIFETIME_DESC[:45],
                },
                "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}},
            }
        },
    )
    if ok:
        loc_id = o["data"]["id"]
        print(f"  created localization {loc_id}")
    else:
        detail = json.dumps(o.get("errors", o))
        print(f"  create localization -> {s} {detail[:200]}")
        # if duplicate, we need the id — fetch via subscription-style workaround not available; try GET instance if we know id from error

    s, o = a.call("GET", f"/v2/inAppPurchases/{iid}/pricePoints?filter[territory]=USA&limit=400")
    pp = closest_price_point(o.get("data", []), LIFETIME["price"])
    if pp:
        body = {
            "data": {
                "type": "inAppPurchasePriceSchedules",
                "relationships": {
                    "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                    "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p}"}]},
                },
            },
            "included": [
                {
                    "type": "inAppPurchasePrices",
                    "id": "${p}",
                    "attributes": {"startDate": None},
                    "relationships": {
                        "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": pp}}
                    },
                }
            ],
        }
        s, o, ok = ok_post("/v1/inAppPurchasePriceSchedules", body)
        if not ok:
            s, o, ok = ok_post("/v2/inAppPurchasePriceSchedules", body)
        print(f"  lifetime price ${LIFETIME['price']} -> {s}" + ("" if ok else f" {json.dumps(o.get('errors', o))[:200]}"))

    # re-check states
    print("\n== final states ==")
    s, o = a.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptions?limit=50")
    for sub in o["data"]:
        print(f"  {sub['attributes']['productId']}: {sub['attributes']['state']}")
    s, o = a.call("GET", f"/v1/apps/{APP}/inAppPurchasesV2?filter[productId]={LIFETIME['productId']}&limit=5")
    print(f"  {LIFETIME['productId']}: {o['data'][0]['attributes']['state']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
