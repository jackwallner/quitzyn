#!/usr/bin/env python3
"""Create the Bloom+ IAPs (2 auto-renewable subs + 1 lifetime) on ASC.

Idempotent-ish: skips creation when a product with the target productId
already exists. Pricing uses the USA price point closest to the target
customer price; ASC equalizes other territories from the base.
"""
import sys
import asc_api as a

APP = "6784788496"
GROUP_REF = "Bloom+"
USA = "USA"

SUBS = [
    {"productId": "com.jackwallner.quitzyn.pro.monthly", "name": "Bloom+ Monthly",
     "period": "ONE_MONTH", "price": "4.99", "trial": None},
    {"productId": "com.jackwallner.quitzyn.pro.yearly", "name": "Bloom+ Yearly",
     "period": "ONE_YEAR", "price": "29.99", "trial": "ONE_WEEK"},
]
LIFETIME = {"productId": "com.jackwallner.quitzyn.pro.lifetime",
            "name": "Bloom+ Lifetime", "price": "59.99"}


def req(method, path, body=None, ok=(200, 201)):
    s, o = a.call(method, path, body)
    label = f"{method} {path.split('?')[0]}"
    if s not in ok:
        errs = o.get("errors", [])
        detail = "; ".join(e.get("detail", e.get("title", "")) for e in errs) or o
        print(f"  ! {label} -> {s}: {detail}")
        return s, o, False
    print(f"  ✓ {label} -> {s}")
    return s, o, True


def closest_price_point(points, target):
    tf = float(target)
    best, bestd = None, 1e9
    for p in points:
        cp = p["attributes"].get("customerPrice")
        if cp is None:
            continue
        d = abs(float(cp) - tf)
        if d < bestd:
            best, bestd = p, d
    return best


# ---- subscription group -------------------------------------------------
print("== subscription group ==")
s, o = a.call("GET", f"/v1/apps/{APP}/subscriptionGroups?limit=50")
group = None
for g in o.get("data", []):
    if g["attributes"].get("referenceName") == GROUP_REF:
        group = g["id"]
if group:
    print(f"  ✓ group exists: {group}")
else:
    s, o, ok = req("POST", "/v1/subscriptionGroups", {"data": {
        "type": "subscriptionGroups", "attributes": {"referenceName": GROUP_REF},
        "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
    group = o["data"]["id"] if ok else None
    if group:
        req("POST", "/v1/subscriptionGroupLocalizations", {"data": {
            "type": "subscriptionGroupLocalizations",
            "attributes": {"name": "Bloom+", "locale": "en-US"},
            "relationships": {"subscriptionGroup": {"data": {
                "type": "subscriptionGroups", "id": group}}}}})

# existing subscriptions in group
existing = {}
if group:
    s, o = a.call("GET", f"/v1/subscriptionGroups/{group}/subscriptions?limit=200")
    for sub in o.get("data", []):
        existing[sub["attributes"].get("productId")] = sub["id"]

# ---- subscriptions ------------------------------------------------------
for spec in SUBS:
    print(f"== subscription {spec['productId']} ==")
    sid = existing.get(spec["productId"])
    if sid:
        print(f"  ✓ exists: {sid}")
    else:
        s, o, ok = req("POST", "/v1/subscriptions", {"data": {
            "type": "subscriptions",
            "attributes": {"name": spec["name"], "productId": spec["productId"],
                           "subscriptionPeriod": spec["period"], "familySharable": False,
                           "groupLevel": 1},
            "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": group}}}}})
        sid = o["data"]["id"] if ok else None
    if not sid:
        continue
    # localization
    req("POST", "/v1/subscriptionLocalizations", {"data": {
        "type": "subscriptionLocalizations",
        "attributes": {"name": spec["name"], "locale": "en-US"},
        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
    # price
    s, o = a.call("GET", f"/v1/subscriptions/{sid}/pricePoints?filter[territory]={USA}&limit=400")
    pp = closest_price_point(o.get("data", []), spec["price"])
    if pp:
        print(f"    price point {pp['id']} = {pp['attributes'].get('customerPrice')}")
        req("POST", "/v1/subscriptionPrices", {"data": {
            "type": "subscriptionPrices",
            "attributes": {"preserveCurrentPrice": False},
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": sid}},
                "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": pp["id"]}}}}})
    else:
        print("    ! no USA price point found")
    # free trial
    if spec["trial"]:
        req("POST", "/v1/subscriptionIntroductoryOffers", {"data": {
            "type": "subscriptionIntroductoryOffers",
            "attributes": {"duration": spec["trial"], "numberOfPeriods": 1,
                           "offerMode": "FREE_TRIAL"},
            "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})

# ---- lifetime non-consumable -------------------------------------------
print(f"== lifetime {LIFETIME['productId']} ==")
s, o = a.call("GET", f"/v1/apps/{APP}/inAppPurchasesV2?filter[productId]={LIFETIME['productId']}&limit=5")
iap = o["data"][0]["id"] if o.get("data") else None
if iap:
    print(f"  ✓ exists: {iap}")
else:
    s, o, ok = req("POST", "/v2/inAppPurchases", {"data": {
        "type": "inAppPurchases",
        "attributes": {"name": LIFETIME["name"], "productId": LIFETIME["productId"],
                       "inAppPurchaseType": "NON_CONSUMABLE"},
        "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
    iap = o["data"]["id"] if ok else None
if iap:
    req("POST", "/v1/inAppPurchaseLocalizations", {"data": {
        "type": "inAppPurchaseLocalizations",
        "attributes": {"name": LIFETIME["name"], "locale": "en-US"},
        "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap}}}}})
    # price schedule
    s, o = a.call("GET", f"/v2/inAppPurchases/{iap}/pricePoints?filter[territory]={USA}&limit=400")
    pp = closest_price_point(o.get("data", []), LIFETIME["price"])
    if pp:
        print(f"    price point {pp['id']} = {pp['attributes'].get('customerPrice')}")
        req("POST", "/v2/inAppPurchasePriceSchedules", {
            "data": {"type": "inAppPurchasePriceSchedules", "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap}},
                "baseTerritory": {"data": {"type": "territories", "id": USA}},
                "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p}"}]}}},
            "included": [{"type": "inAppPurchasePrices", "id": "${p}",
                          "attributes": {"startDate": None},
                          "relationships": {"inAppPurchasePricePoint": {"data": {
                              "type": "inAppPurchasePricePoints", "id": pp["id"]}}}}]})
    else:
        print("    ! no USA price point found")

print("done.")
