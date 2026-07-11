#!/usr/bin/env python3
"""Attach IAPs + app version to a review submission (first-release flow)."""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_api as a
import asc_lib as L

APP = "6784788496"


def main() -> int:
    version = os.environ.get("ASC_APP_VERSION", "1.0")
    kid, iss, kp = L.load_credentials()
    client = L.ASCClient(L.bearer_token(kid, iss, kp))
    app = L.find_app(client, L.bundle_id_from_appfile())
    app_id = app["id"]
    ver = L.find_version_by_string(client, app_id, version)
    if not ver:
        print(f"ERROR: version {version} not found")
        return 1
    ver_id = ver["id"]

    iap_ids: list[str] = []
    s, o = a.call("GET", f"/v1/apps/{APP}/subscriptionGroups?limit=50")
    gid = next(g["id"] for g in o["data"] if g["attributes"].get("referenceName") == "Bloom+")
    s, o = a.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptions?limit=50")
    for sub in o["data"]:
        pid = sub["attributes"]["productId"]
        state = sub["attributes"]["state"]
        print(f"sub {pid}: {state}")
        if state in ("READY_TO_SUBMIT", "APPROVED", "WAITING_FOR_REVIEW"):
            iap_ids.append(sub["id"])
    s, o = a.call(
        "GET",
        f"/v1/apps/{APP}/inAppPurchasesV2?filter[productId]=com.jackwallner.quitzyn.pro.lifetime&limit=5",
    )
    life = o["data"][0]
    print(f"lifetime: {life['attributes']['state']}")
    if life["attributes"]["state"] in ("READY_TO_SUBMIT", "APPROVED", "WAITING_FOR_REVIEW"):
        iap_ids.append(life["id"])

    subs = L.list_all(
        client,
        f"/reviewSubmissions?filter[app]={app_id}&filter[state]=READY_FOR_REVIEW,UNRESOLVED_ISSUES&limit=5",
    )
    if subs:
        sub_id = subs[0]["id"]
        print(f"reuse reviewSubmission {sub_id}")
    else:
        created = client.post(
            "/reviewSubmissions",
            {
                "data": {
                    "type": "reviewSubmissions",
                    "attributes": {"platform": "IOS"},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
        )
        sub_id = created["data"]["id"]
        print(f"created reviewSubmission {sub_id}")

    def add_item(rel_name: str, rel_type: str, rel_id: str, label: str) -> None:
        try:
            client.post(
                "/reviewSubmissionItems",
                {
                    "data": {
                        "type": "reviewSubmissionItems",
                        "relationships": {
                            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                            rel_name: {"data": {"type": rel_type, "id": rel_id}},
                        },
                    }
                },
            )
            print(f"  added {label}")
        except Exception as e:
            print(f"  add {label}: {e}")

    add_item("appStoreVersions", "appStoreVersions", ver_id, f"version {version}")
    for iid in iap_ids:
        add_item("inAppPurchases", "inAppPurchases", iid, f"iap {iid}")

    print(f"reviewSubmission {sub_id} staged (not submitted)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
