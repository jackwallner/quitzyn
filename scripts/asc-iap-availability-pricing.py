#!/usr/bin/env python3
"""Set subscription/IAP availability (all territories), then base prices + trial."""
import asc_api as a, json

APP = "6784788496"
PRICES = {"com.jackwallner.quitzyn.pro.monthly": "4.99",
          "com.jackwallner.quitzyn.pro.yearly": "29.99"}
TRIAL_PRODUCT = "com.jackwallner.quitzyn.pro.yearly"


def post(path, body, ok=(200, 201)):
    s, o = a.call("POST", path, body)
    return s, o, s in ok


# territories
s, o = a.call("GET", "/v1/territories?limit=200")
terrs = [t["id"] for t in o["data"]]
terr_data = [{"type": "territories", "id": t} for t in terrs]
print("territories:", len(terrs))

# subs
s, o = a.call("GET", f"/v1/apps/{APP}/subscriptionGroups?limit=50")
grp = [g["id"] for g in o["data"] if g["attributes"].get("referenceName") == "Bloom+"][0]
s, o = a.call("GET", f"/v1/subscriptionGroups/{grp}/subscriptions?limit=50")
subs = {x["attributes"]["productId"]: x["id"] for x in o["data"]}

# --- subscription availability ---
for pid, sid in subs.items():
    s, o, ok = post("/v1/subscriptionAvailabilities", {"data": {
        "type": "subscriptionAvailabilities",
        "attributes": {"availableInNewTerritories": True},
        "relationships": {
            "subscription": {"data": {"type": "subscriptions", "id": sid}},
            "availableTerritories": {"data": terr_data}}}})
    print(f"sub availability {pid} -> {s}" + ("" if ok else " " + json.dumps(o.get("errors", o))[:200]))

# --- base prices (initial price uses startDate null) ---
for pid, price in PRICES.items():
    sid = subs[pid]
    s, o = a.call("GET", f"/v1/subscriptions/{sid}/pricePoints?filter[territory]=USA&limit=400")
    pp = [p for p in o["data"] if p["attributes"].get("customerPrice") == price][0]["id"]
    s, o, ok = post("/v1/subscriptionPrices", {"data": {"type": "subscriptionPrices",
        "attributes": {"startDate": None},
        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
            "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": pp}}}}})
    print(f"price {pid} {price} -> {s}" + ("" if ok else " " + json.dumps(o.get("errors", o))[:240]))

# --- free trial across all territories ---
sid = subs[TRIAL_PRODUCT]
ok_n = err_n = 0
sample = []
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
        if len(sample) < 2:
            sample.append((t, o.get("errors", o)))
print(f"free trial: {ok_n} ok, {err_n} err")
for t, e in sample:
    print("  ", t, json.dumps(e)[:200])

# --- lifetime availability ---
s, o = a.call("GET", f"/v1/apps/{APP}/inAppPurchasesV2?filter[productId]=com.jackwallner.quitzyn.pro.lifetime&limit=5")
iap = o["data"][0]["id"]
s, o, ok = post("/v1/inAppPurchaseAvailabilities", {"data": {
    "type": "inAppPurchaseAvailabilities",
    "attributes": {"availableInNewTerritories": True},
    "relationships": {
        "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap}},
        "availableTerritories": {"data": terr_data}}}})
print(f"lifetime availability -> {s}" + ("" if ok else " " + json.dumps(o.get("errors", o))[:200]))
print("done.")
