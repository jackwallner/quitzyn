# Localization & ASO — Sober

## Source of truth

| File | Purpose |
|------|---------|
| `scripts/aso_native_metadata.py` | Native **name**, **subtitle**, **keywords**, **description** for all **50** ASC locales |
| `scripts/aso-apply-locale-optimizations.py` | Writes `fastlane/metadata/<locale>/` (dedupes keywords vs name/subtitle) |

Apply after edits:

```bash
python3 scripts/aso-apply-locale-optimizations.py
python3 scripts/validate-asc-metadata.py
```

For a focused pass, list only the locale folders to update:

```bash
python3 scripts/aso-apply-locale-optimizations.py en-US de-DE
python3 scripts/validate-asc-metadata.py en-US de-DE
```

Keyword cleanup removes repeated tokens and tokens already present in the name or subtitle. Keep distinct inflections when Apple autocomplete or live search supports them.

Upload draft:

```bash
./scripts/asc-finish-missed.sh
# or API only: ./scripts/asc-upload-metadata.sh
# names/subtitles: SKIP_SCREENSHOTS=true ./scripts/upload-appstore-metadata.sh
```

## Backups

| Path | When |
|------|------|
| `fastlane/metadata.bak.20260525-190649` | First ASC pull |
| `fastlane/metadata.bak.pre-upload-native-20260526-090332` | Before native multi-language upload |

Restore:

```bash
./scripts/restore-appstore-metadata.sh fastlane/metadata.bak.pre-upload-native-20260526-090332
```

## Astro (91 Search Ads countries)

Keywords per country: `./scripts/astro-sync-all-stores.sh`  
Uses native fastlane text + `scripts/astro-keywords-us.json` for US.

Prune junk: `./scripts/astro-prune-all-stores.sh`

## Re-pull from ASC

```bash
eval "$(python3 scripts/asc-ensure-draft-version.py | grep '^export ')"
ASC_APP_VERSION="$ASC_APP_VERSION" ./scripts/pull-appstore-metadata.sh
```

**Warning:** Re-pull can wipe local-only fields if ASC version localizations are empty. Re-run `aso-apply-locale-optimizations.py` after pull if needed.
