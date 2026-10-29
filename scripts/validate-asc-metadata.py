#!/usr/bin/env python3
"""Validate App Store metadata fields for the requested locales."""
from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
METADATA = ROOT / "fastlane" / "metadata"
DEFAULT_LOCALES = (
    "en-US",
    "de-DE",
    "en-GB",
    "sv",
    "cs",
    "fi",
    "ru",
    "da",
    "nl-NL",
    "ar-SA",
    "es-MX",
    "en-CA",
    "en-AU",
    "fr-CA",
)
LIMITS = {
    "name": 30,
    "subtitle": 30,
    "keywords": 100,
    "promotional_text": 170,
    "description": 4000,
}
TOKEN_PATTERN = re.compile(r"[^\W_]+", re.UNICODE)
DECIMAL_PRICE_PATTERN = re.compile(r"(?<!\d)\d+[.,]\d{2}(?!\d)")


def read(locale: str, field: str) -> str:
    path = METADATA / locale / f"{field}.txt"
    if not path.is_file():
        raise FileNotFoundError(path)
    return path.read_text(encoding="utf-8").rstrip("\r\n")


def normalize(value: str) -> str:
    return unicodedata.normalize("NFKC", value).casefold()


def tokens(text: str) -> list[str]:
    return [normalize(token) for token in TOKEN_PATTERN.findall(text)]


def validate_locale(locale: str) -> list[str]:
    errors: list[str] = []
    fields: dict[str, str] = {}
    for field, limit in LIMITS.items():
        try:
            value = read(locale, field)
        except FileNotFoundError:
            errors.append(f"{locale}: missing {field}.txt")
            continue
        fields[field] = value
        if value != value.strip():
            errors.append(f"{locale}: {field} has leading or trailing whitespace")
        if len(value) > limit:
            errors.append(f"{locale}: {field} is {len(value)} characters, limit {limit}")
        if "\u2014" in value:
            errors.append(f"{locale}: {field} contains an em dash")
        if any(unicodedata.category(character) == "Sc" for character in value):
            errors.append(f"{locale}: {field} contains a currency symbol")
        if DECIMAL_PRICE_PATTERN.search(value):
            errors.append(f"{locale}: {field} contains a decimal price")

    keywords = fields.get("keywords")
    if keywords is None:
        return errors
    if any(character.isspace() for character in keywords):
        errors.append(f"{locale}: keywords must be comma-separated without spaces")

    raw_tokens = keywords.split(",")
    if not keywords or any(not token for token in raw_tokens):
        errors.append(f"{locale}: keywords contain an empty token")
    keyword_tokens = [normalize(part) for part in raw_tokens if part]
    seen: set[str] = set()
    for token in keyword_tokens:
        if token in seen:
            errors.append(f"{locale}: duplicate keyword token {token!r}")
        seen.add(token)

    name_and_subtitle = set(tokens(fields.get("name", "")) + tokens(fields.get("subtitle", "")))
    for token in keyword_tokens:
        if token in name_and_subtitle:
            errors.append(f"{locale}: keyword {token!r} repeats name or subtitle")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("locales", nargs="*", default=list(DEFAULT_LOCALES))
    args = parser.parse_args()

    errors = [error for locale in args.locales for error in validate_locale(locale)]
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Validated {len(args.locales)} locales: {', '.join(args.locales)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
