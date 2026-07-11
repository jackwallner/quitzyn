#!/usr/bin/env python3
"""Pack keywords + sync generate script → aso_native_metadata → fastlane."""
from __future__ import annotations

import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent

sys.path.insert(0, str(SCRIPTS))
from locale_aso_spec import LOCALE_ASO  # noqa: E402
from pack_quitzyn_keywords import (  # noqa: E402
    pack_keywords,
    validate_packed_keywords,
    validate_title_subtitle,
)


def load_generate_module():
    spec = importlib.util.spec_from_file_location(
        "generate_quitzyn_native_metadata",
        SCRIPTS / "generate_quitzyn_native_metadata.py",
    )
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def rewrite_core_in_generate_source(packed: dict[str, tuple[str, str, str]]) -> None:
    path = SCRIPTS / "generate_quitzyn_native_metadata.py"
    text = path.read_text(encoding="utf-8")
    lines = ["CORE: dict[str, tuple[str, str, str]] = {"]
    for loc in sorted(packed):
        name, sub, kw = packed[loc]
        lines.append(f'    "{loc}": (')
        lines.append(f"        {json.dumps(name, ensure_ascii=False)},")
        lines.append(f"        {json.dumps(sub, ensure_ascii=False)},")
        lines.append(f"        {json.dumps(kw, ensure_ascii=False)},")
        lines.append("    ),")
    lines.append("}")
    new_core = "\n".join(lines)
    text, n = re.subn(
        r"CORE: dict\[str, tuple\[str, str, str\]\] = \{.*?\n\}",
        new_core,
        text,
        count=1,
        flags=re.S,
    )
    if n != 1:
        raise RuntimeError("Failed to rewrite CORE in generate_quitzyn_native_metadata.py")
    path.write_text(text, encoding="utf-8")


def main() -> int:
    gen = load_generate_module()
    packed: dict[str, tuple[str, str, str]] = {}

    for loc, (_name, _sub, _kw) in gen.CORE.items():
        spec = LOCALE_ASO.get(loc)
        if not spec:
            print(f"MISSING SPEC: {loc}")
            return 1
        name, sub = spec.title, spec.subtitle
        keywords = pack_keywords(name, sub, spec.keyword_pool, limit=100)
        packed[loc] = (name, sub, keywords)
        gen.CORE[loc] = packed[loc]

    leak_errs: list[str] = []
    for loc, (name, sub, kw) in packed.items():
        leak_errs.extend(validate_packed_keywords(loc, kw))
        leak_errs.extend(validate_title_subtitle(loc, name, sub))
        from pack_quitzyn_keywords import _overlaps_indexed, indexed_terms  # noqa: WPS433

        indexed = indexed_terms(name, sub)
        for term in kw.split(","):
            t = term.strip().lower()
            if t and _overlaps_indexed(t, indexed):
                leak_errs.append(f"{loc}: keyword {t!r} overlaps title/subtitle")
    if leak_errs:
        for e in leak_errs:
            print("LOCALE KEYWORD ERROR:", e)
        return 1

    errs = gen.validate()
    if errs:
        for e in errs:
            print("VALIDATION ERROR:", e)
        return 1

    rewrite_core_in_generate_source(packed)
    gen.OUT.write_text(gen.emit_py(), encoding="utf-8")
    print(f"Wrote {gen.OUT} ({len(packed)} locales)")

    subprocess.run([sys.executable, str(SCRIPTS / "aso-apply-locale-optimizations.py")], check=True)

    lengths = [len(kw) for _, _, kw in packed.values()]
    print(
        f"Keyword lengths: min={min(lengths)} max={max(lengths)} "
        f"avg={sum(lengths)/len(lengths):.1f} "
        f"≥95 chars: {sum(1 for x in lengths if x >= 95)}/{len(lengths)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
