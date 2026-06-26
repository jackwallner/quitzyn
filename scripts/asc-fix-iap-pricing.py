#!/usr/bin/env python3
"""Set pricing for the Bloom+ IAPs: sub prices, free trial, lifetime schedule."""
import asc_api as a, json, datetime

APP = "6784788496"
START = "2026-06-28"  # earliest allowed effective date
PRICES = {"com.jackwallner.quitzyn.pro.monthly": "4.99",
          "com.jackwallner.quitzyn.pro.yearly": "29.99"}
TRIAL_PRODUCT = "com.jackwallner.quitzyn.pro.yearly"


def post(path, body, ok=(200, 201)):
    s, o = a.call("POST", path, body)
    if s not in ok:
        return s, o, False
    return s, o, True


# resolve subs
s, o = a.call("GET", f"/v1/apps/{APP}/subscriptionGroups?limit=50")
grp = [g["id"] for g in o["data"] if g["attributes"].get("referenceName") == "Bloom+"][0]
s, o = a.call("GET", f"/v1/subscriptionGroups/{grp}/subscriptions?limit=50")
subs = {x["attributes"]["productId"]: x["id"] for x in o["data"]}

# --- subscription prices ---
for pid, price in PRICES.items():
    sid = subs[pid]
    s, o = a.call("GET", f"/v1/subscriptions/{sid}/pricePoints?filter[territory]=USA&limit=400")
    pp = [p for p in o["data"] if p["attributes"].get("customerPrice") == price][0]["id"]
    s, o, ok = post("/v1/subscriptionPrices", {"data": {"type": "subscriptionPrices",
        "attributes": {"startDate": START, "preserveCurrentPrice": False},
        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
            "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": pp}}}}})
    print(f"price {pid} {price} -> {s}" + ("" if ok else " " + json.dumps(o.get("errors", o))))

# --- free trial across all territories ---
sid = subs[TRIAL_PRODUCT]
s, o = a.call("GET", "/v1/territories?limit=200")
terrs = [t["id"] for t in o.get("data", [])]
print(f"territories: {len(terrs)}")
ok_n = err_n = 0
errs_sample = []
for t in terrs:
    s, o, ok = post("/v1/subscriptionIntroductoryOffers", {"data": {
        "type": "subscriptionIntroductoryOffers",
        "attributes": {"duration": "ONE_WEEK", "numberOfPeriods": 1, "offerMode": "FREE_TRIAL"},
        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
            "territory": {"data": {"type": "territories", "id": t}}}}})
    if ok:
        ok_n += 1
    else:
        err_n += 1
        if len(errs_sample) < 3:
            errs_sample.append((t, o.get("errors", o)))
print(f"free trial: {ok_n} ok, {err_n} err")
for t, e in errs_sample:
    print("  ", t, json.dumps(e))

# --- lifetime price schedule (/v1) ---
s, o = a.call("GET", f"/v1/apps/{APP}/inAppPurchasesV2?filter[productId]=com.jackwallner.quitzyn.pro.lifetime&limit=5")
iap = o["data"][0]["id"]
s, o = a.call("GET", f"/v2/inAppPurchases/{iap}/pricePoints?filter[territory]=USA&limit=400")
pp = [p for p in o["data"] if p["attributes"].get("customerPrice") == "59.99"][0]["id"]
for sd in (None, START):
    body = {"data": {"type": "inAppPurchasePriceSchedules", "relationships": {
        "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap}},
        "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
        "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p}"}]}}},
        "included": [{"type": "inAppPurchasePrices", "id": "${p}",
            "attributes": {"startDate": sd},
            "relationships": {"inAppPurchasePricePoint": {"data": {
                "type": "inAppPurchasePricePoints", "id": pp}}}}]}
    s, o, ok = post("/v1/inAppPurchasePriceSchedules", body)
    print(f"lifetime schedule startDate={sd} -> {s}" + ("" if ok else " " + json.dumps(o.get("errors", o))))
    if ok:
        break
print("done.")
