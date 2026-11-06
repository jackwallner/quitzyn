#!/usr/bin/env bash
set -euo pipefail

kit_root=$(cd "$(dirname "$0")/.." && pwd)
repo_root=$(git -C "$kit_root" rev-parse --show-toplevel)
python="$kit_root/.venv/bin/python"
app_json="$kit_root/app.json"
locale_rows=$("$python" - "$app_json" "$@" <<'PY'
import json
import sys
from pathlib import Path

app = json.loads(Path(sys.argv[1]).read_text())
requested = {part for arg in sys.argv[2:] for part in arg.split(",") if part}
targets = app["targets"]
if requested and "all" not in requested:
    selected = [item for item in targets if item["store_locale"] in requested or item["lang"] in requested]
    known = {item[key] for item in targets for key in ("store_locale", "lang")}
    unknown = requested - known - {"en-US"}
    if unknown:
        raise SystemExit(f"unknown locale(s): {', '.join(sorted(unknown))}")
else:
    selected = targets

for item in selected:
    print(f"{item['store_locale']}|{item['lang']}")
PY
)

raw_root="$kit_root/raw"
headers="$kit_root/copy/headers.json"
config="$kit_root/frames.json"
out="$kit_root/out"
catalog="$repo_root/Shared/Localizable.xcstrings"
status=0

if ! "$python" "$kit_root/tools/reskin.py" --config "$config" --raw-root "$raw_root" \
    --headers "$headers" --locale en-US --out "$out"; then
    exit 1
fi

while IFS='|' read -r locale lang; do
    [[ -n "$locale" ]] || continue
    printf 'Processing %s\n' "$locale"
    if ! "$python" "$kit_root/tools/reskin.py" --config "$config" --raw-root "$raw_root" \
        --headers "$headers" --locale "$locale" --out "$out"; then
        status=1
        continue
    fi
    if ! "$python" "$kit_root/tools/sheet.py" --config "$config" --locale "$locale" \
        --out-root "$out" --base-label en-US; then
        status=1
        continue
    fi
    cp "$out/sheets/$locale-phone.jpg" "$kit_root/sheets/$locale-phone.jpg"
    if ! "$python" "$kit_root/tools/gate.py" --config "$config" --raw-root "$raw_root" \
        --headers "$headers" --out-root "$out" --locale "$locale" \
        --catalog "$catalog" --lang "$lang"; then
        status=1
    fi
done <<< "$locale_rows"

exit "$status"
