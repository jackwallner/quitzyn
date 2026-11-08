#!/usr/bin/env bash
set -euo pipefail

kit_root=$(cd "$(dirname "$0")/.." && pwd)
repo_root=$(git -C "$kit_root" rev-parse --show-toplevel)
python="$kit_root/.venv/bin/python"
app_json="$kit_root/app.json"
id_file="$kit_root/.capture-id"
mkdir -p "$kit_root/raw"
trap 'rm -f "$id_file"' EXIT

locale_rows=()
locale_args=()
scene_plan=""
skip_english=0
while (($#)); do
    case "$1" in
        --scenes)
            scene_plan=${2:?expected locale-specific scenes after --scenes}
            shift 2
            ;;
        --skip-english)
            skip_english=1
            shift
            ;;
        *)
            locale_args+=("$1")
            shift
            ;;
    esac
done

locale_output=$("$python" - "$app_json" "$scene_plan" "$skip_english" ${locale_args[@]+"${locale_args[@]}"} <<'PY'
import json
import sys
from pathlib import Path

app = json.loads(Path(sys.argv[1]).read_text())
scene_plan = sys.argv[2]
skip_english = sys.argv[3] == "1"
requested = {part for arg in sys.argv[4:] for part in arg.split(",") if part}
targets = app["targets"]
if requested and "all" not in requested:
    selected = [item for item in targets if item["store_locale"] in requested or item["lang"] in requested]
    unknown = requested - {"en-US"} - {item[key] for item in targets for key in ("store_locale", "lang")}
    if unknown:
        raise SystemExit(f"unknown locale(s): {', '.join(sorted(unknown))}")
else:
    selected = targets

allowed_scenes = {"home", "garden", "timeline", "journal", "craving", "checkin", "patterns"}
scenes_by_locale = {}
if scene_plan:
    for entry in scene_plan.split(";"):
        locale, values = entry.split("=", 1)
        scenes = [scene for scene in values.split(",") if scene]
        if locale in scenes_by_locale or not scenes or len(set(scenes)) != len(scenes) or set(scenes) - allowed_scenes:
            raise SystemExit(f"invalid screenshot scene list for {locale}: {values}")
        scenes_by_locale[locale] = scenes
    selected_names = {item["store_locale"] for item in selected}
    if set(scenes_by_locale) != selected_names:
        raise SystemExit("--scenes must name every selected store locale exactly once")

rows = []
if not skip_english:
    rows.append(("en-US", "en", "(en)", "en_US", ""))
for item in selected:
    scenes = ",".join(scenes_by_locale.get(item["store_locale"], []))
    rows.append((item["store_locale"], item["lang"], item["apple_languages"], item["apple_locale"], scenes))
for row in rows:
    print("|".join(row))
PY
)
while IFS= read -r line; do locale_rows+=("$line"); done <<< "$locale_output"

locale_file="$repo_root/SoberUITests/StoreScreenshotLocales.json"
"$python" - "$locale_file" "${locale_rows[@]}" <<'PY'
import json
import sys
from pathlib import Path

rows = [row.split("|") for row in sys.argv[2:]]
locales = []
for row in rows:
    item = {"store_locale": row[0], "language": row[1], "region": row[3]}
    if len(row) > 4 and row[4]:
        item["scenes"] = row[4].split(",")
    locales.append(item)
Path(sys.argv[1]).write_text(json.dumps({"locales": locales}, ensure_ascii=False, indent=2) + "\n")
PY

cd "$repo_root"
gh-sim test \
    --scheme SoberUITests \
    --device "iPhone 17 Pro Max" \
    --only SoberUITests/StoreScreenshotLocalizationUITests/testCaptureStoreFrames \
    --id-file "$id_file"

run_id=$(<"$id_file")
attachments_root="${GH_SIM_HOME:-$HOME/.gh-sim}/results/$run_id/attachments"
"$python" - "$attachments_root" "$kit_root/raw" "${locale_rows[@]}" <<'PY'
import json
import shutil
import sys
from pathlib import Path

attachments_root = Path(sys.argv[1])
raw_root = Path(sys.argv[2])
rows = [row.split("|") for row in sys.argv[3:]]
all_scenes = ["home", "garden", "timeline", "journal", "craving", "checkin", "patterns"]
manifest_path = attachments_root / "manifest.json"
if not manifest_path.is_file():
    raise SystemExit(f"capture: missing attachment manifest at {manifest_path}")

manifest = json.loads(manifest_path.read_text())
items = [item for suite in manifest for item in suite.get("attachments", [])]
copied = 0
for row in rows:
    locale = row[0]
    scenes = row[4].split(",") if len(row) > 4 and row[4] else all_scenes
    for scene in scenes:
        prefix = f"{locale}__{scene}_"
        matches = [item for item in items if item.get("suggestedHumanReadableName", "").startswith(prefix)]
        if len(matches) != 1:
            raise SystemExit(f"capture: expected one attachment for {locale}/{scene}, found {len(matches)}")
        item = matches[0]
        source = attachments_root / item["exportedFileName"]
        destination = raw_root / locale / "phone" / f"{scene}.png"
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        copied += 1

print(f"sorted {copied} real app captures for {len(rows)} locales")
PY
"$kit_root/tools/process.sh" ${locale_args[@]+"${locale_args[@]}"}
printf 'XCUITest capture completed for %s locales in gh-sim run %s\n' "${#locale_rows[@]}" "$run_id"
