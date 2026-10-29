#!/usr/bin/env python3
"""Apply native metadata to all fastlane locales or a selected locale set."""
from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "fastlane/metadata"
sys.path.insert(0, str(Path(__file__).parent))
from aso_native_metadata import LOCALES  # noqa: E402


def indexed_terms(name: str, subtitle: str) -> set[str]:
    text = f"{name} {subtitle}"
    terms: set[str] = set()
    for w in re.findall(r"[a-z0-9\u0080-\uffff]+", text, flags=re.I):
        if len(w) >= 2:
            terms.add(unicodedata.normalize("NFKC", w).casefold())
    return terms


def dedupe_keywords(name: str, subtitle: str, keywords_csv: str) -> str:
    indexed = indexed_terms(name, subtitle)
    kept: list[str] = []
    seen: set[str] = set()
    for raw in keywords_csv.replace(" ", "").split(","):
        kw = unicodedata.normalize("NFKC", raw.strip()).casefold()
        if not kw or kw in indexed or kw in seen:
            continue
        seen.add(kw)
        kept.append(kw)
    return ",".join(kept)


def trim_field(s: str, limit: int) -> str:
    s = s.strip()
    return s[:limit] if len(s) > limit else s


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("locales", nargs="*", help="locale folders to update, defaults to all")
    args = parser.parse_args()
    requested = set(args.locales)
    unknown = sorted(requested - LOCALES.keys())
    if unknown:
        parser.error(f"unknown locale(s): {', '.join(unknown)}")

    report: dict[str, dict] = {}
    errors: list[str] = []

    locale_dirs = sorted(
        loc_dir
        for loc_dir in META.iterdir()
        if loc_dir.is_dir()
        and loc_dir.name != "review_information"
        and loc_dir.name in LOCALES
        and (not requested or loc_dir.name in requested)
    )
    for loc_dir in locale_dirs:
        loc = loc_dir.name
        if loc not in LOCALES:
            continue
        data = LOCALES[loc]
        name = trim_field(data["name"], 30)
        subtitle = trim_field(data["subtitle"], 30)
        keywords = trim_field(dedupe_keywords(name, subtitle, data["keywords"]), 100)
        description = data["description"].strip()
        promotional = trim_field(data.get("promotional", ""), 170)
        release_notes = data.get("release_notes", "").strip()

        for field, val, lim in [
            ("name", name, 30),
            ("subtitle", subtitle, 30),
            ("keywords", keywords, 100),
            ("promotional", promotional, 170),
        ]:
            if len(val) > lim:
                errors.append(f"{loc}/{field}: {len(val)}>{lim}")

        old_name = (loc_dir / "name.txt").read_text(encoding="utf-8").strip() if (loc_dir / "name.txt").exists() else ""
        old_sub = (loc_dir / "subtitle.txt").read_text(encoding="utf-8").strip() if (loc_dir / "subtitle.txt").exists() else ""
        old_kw = (loc_dir / "keywords.txt").read_text(encoding="utf-8").strip() if (loc_dir / "keywords.txt").exists() else ""

        (loc_dir / "name.txt").write_text(name + "\n", encoding="utf-8")
        (loc_dir / "subtitle.txt").write_text(subtitle + "\n", encoding="utf-8")
        (loc_dir / "keywords.txt").write_text(keywords + "\n", encoding="utf-8")
        (loc_dir / "description.txt").write_text(description + "\n", encoding="utf-8")
        if promotional:
            (loc_dir / "promotional_text.txt").write_text(promotional + "\n", encoding="utf-8")
        if release_notes:
            (loc_dir / "release_notes.txt").write_text(release_notes + "\n", encoding="utf-8")

        report[loc] = {
            "name": {"old": old_name, "new": name, "len": len(name)},
            "subtitle": {"old": old_sub, "new": subtitle, "len": len(subtitle)},
            "keywords": {"old": old_kw, "new": keywords, "len": len(keywords)},
            "description_chars": len(description),
            "promotional_chars": len(promotional),
            "release_notes_chars": len(release_notes),
        }

    out = ROOT / "scripts" / "aso-locale-optimization-report.json"
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"Updated {len(report)} locales → {out}")
    if errors:
        print("LIMIT ERRORS:", file=sys.stderr)
        for e in errors:
            print(f"  {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
