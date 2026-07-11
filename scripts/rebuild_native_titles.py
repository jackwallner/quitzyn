#!/usr/bin/env python3
"""Rebuild all 50 locale titles with native quit verbs (no English Quit outside en-*)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))

from locale_aso_spec import LOCALE_ASO, EN_KEYWORDS, EN_TITLE, EN_SUBTITLE, EN_PROOF  # noqa: E402
from pack_quitzyn_keywords import (  # noqa: E402
    pack_keywords,
    validate_packed_keywords,
    validate_title_subtitle,
    title_subtitle_overlap,
)

# Native-led titles: {native quit intent} + product terms. en-* only keeps "Quit Zyn".
NATIVE_TITLES: dict[str, str] = {
    "en-US": EN_TITLE,
    "en-GB": EN_TITLE,
    "en-CA": EN_TITLE,
    "en-AU": EN_TITLE,
    "de-DE": "Snus aufhören: Beutel & Zyn",
    "sv": "Sluta snusa: Prillor & snus",
    "da": "Stop snus: Poser & prillor",
    "no": "Slutt med snus: Poser & velo",
    "fi": "Lopeta nuuska: Pussit & snus",
    "nl-NL": "Stop met snus: Zakjes & velo",
    "fr-FR": "Arrêter snus: Sachets & velo",
    "fr-CA": "Arrêter snus: Sachets & velo",
    "es-ES": "Dejar snus: Bolsas & velo",
    "es-MX": "Dejar snus: Bolsas & velo",
    "it": "Smetti snus: Bustine & velo",
    "pt-BR": "Parar snus: Saquinhos & velo",
    "pt-PT": "Parar snus: Saquinhos & velo",
    "ca": "Deixa snus: Bosses & velo",
    "pl": "Rzuć snus: Saszetki & velo",
    "cs": "Přestaň snus: Sáčky & velo",
    "sk": "Prestaň snus: Vrecká & velo",
    "hr": "Prestani snus: Vrećice & velo",
    "sl-SI": "Nehaj snus: Vrečke & velo",
    "hu": "Snus abbahagy: Tasakok & velo",
    "ro": "Oprește snus: Plicuri & velo",
    "ru": "Брось snus: Пакетики & velo",
    "uk": "Кинь snus: Пакетики & velo",
    "el": "Σταμάτα snus: Φακελάκια & velo",
    "tr": "Bırak snus: Poşet & velo",
    "id": "Berhenti snus: Kantong & velo",
    "ms": "Berhenti snus: Kantung & velo",
    "vi": "Bỏ snus: Túi & velo",
    "th": "ถุงนิโคติน: Snus & velo",
    "ar-SA": "إقلاع السنوس: أكياس ونيكوتين",
    "he": "הפסק snus: שקיות וסנוס",
    "ja": "禁煙ポーチ｜スヌース追跡",
    "ko": "스누스 끊기｜파우치 추적",
    "zh-Hans": "戒瘾助手｜尼古丁袋追踪器",
    "zh-Hant": "戒癮助手｜尼古丁袋追蹤器",
    "hi": "स्नूस छोड़ें – पाउच ट्रैकर",
    "bn-BD": "স্নাস ছাড়ুন – পাউচ ট্র্যাকার",
    "ta-IN": "ஸ்னூஸ் விடு – பவுச் டிராக்கர்",
    "te-IN": "స్నూస్ వదులు – పౌచ్ ట్రాకర్",
    "mr-IN": "स्नूस सोडा – पाउच ट्रॅकर",
    "gu-IN": "સ્નસ છોડો – પાઉચ ટ્રેકર",
    "kn-IN": "ಸ್ನೂಸ್ ಬಿಡಿ – ಪಾಉಚ್ ಟ್ರ್ಯಾಕರ್",
    "ml-IN": "സ്നൂസ് നിർത്തുക – പൗച്ച്",
    "pa-IN": "ਸਨੂਸ ਛੱਡੋ – ਪਾਊਚ ਟ੍ਰੈਕਰ",
    "or-IN": "ସ୍ନସ ଛାଡ଼ – ପାଉଚ ଟ୍ରାକର",
    "ur-PK": "سنوس چھوڑیں – پاؤچ ٹریکر",
}

# Subtitles (unchanged from maximized pass unless noted)
NATIVE_SUBTITLES: dict[str, str] = {
    "en-US": EN_SUBTITLE,
    "en-GB": EN_SUBTITLE,
    "en-CA": EN_SUBTITLE,
    "en-AU": EN_SUBTITLE,
}

VERIFICATION: dict[str, str] = {
    "en-US": "US Astro: zyn tracker pop28; native English quit+zyn correct for US/UK/CA/AU only.",
    "en-GB": "Same as en-US; English quit+zyn+pouch SERP validated.",
    "en-CA": "Same as en-US.",
    "en-AU": "Same as en-US.",
    "de-DE": "DE SERP snus aufhören #1 SnusFrei, PouchOut; native aufhören beats English Quit.",
    "sv": "SE SERP sluta snusa #1-8 all native Swedish snus apps; prillor native pouch word.",
    "da": "DK Nordic: stop/slut + poser/prillor; snus culture market.",
    "no": "NO Nordic: slutt med snus pattern; poser=pouches.",
    "fi": "FI: lopeta nuuska native; pussit=pouches Finnish.",
    "nl-NL": "NL: stop met snus; zakjes=pouches native.",
    "fr-FR": "FR SERP arrêter snus #1 Arrêter Snus; sachets native; velo pouch brand in keywords.",
    "fr-CA": "fr-CA same as fr-FR; bilingual but French quit verb leads.",
    "es-ES": "ES SERP dejar snus #1 Dejar Snus; bolsas native; no English Quit.",
    "es-MX": "MX SERP dejar snus + pouch apps; English pouch/nicotine in keywords not title.",
    "it": "IT: smetti=quit Italian; bustine=pouches.",
    "pt-BR": "PT-BR: parar=stop native; saquinhos=pouches.",
    "pt-PT": "PT-PT same pattern as PT-BR.",
    "ca": "Catalan deixa=quit; bosses=pouches.",
    "pl": "PL: rzuć=quit Polish; saszetki=pouches.",
    "cs": "CZ: přestaň=quit; sáčky=pouches.",
    "sk": "SK: prestaň=quit; vrecká=pouches.",
    "hr": "HR: prestani=quit; vrećice=pouches.",
    "sl-SI": "SL: nehaj=quit; vrečke=pouches.",
    "hu": "HU: abbahagy=quit; tasakok=pouches.",
    "ro": "RO: oprește=stop; plicuri=pouches.",
    "ru": "RU: брось=quit; пакетики=pouches; snus/velo loanwords.",
    "uk": "UK: кинь=quit; пакетики=pouches.",
    "el": "EL: σταμάτα=stop; φακελάκια=pouches.",
    "tr": "TR: bırak=quit; poşet=pouch.",
    "id": "ID: berhenti=quit; kantong=pouch.",
    "ms": "MS: berhenti=quit; kantung=pouch.",
    "vi": "VN: bỏ=quit; túi=pouch; nicotine in title for clarity.",
    "th": "TH: เลิก=quit; ถุงนิโคติน=nicotine pouch.",
    "ar-SA": "AR: إقلاع=quit native; أكياس=pouches; removed كيت زين transliteration.",
    "he": "HE: הפסק=stop native; שקיות=pouches.",
    "ja": "JP: 禁煙=native quit; ポーチ&スヌース product; 追跡=track; no クィットザン transliteration.",
    "ko": "KR: 스누스 끊기=native quit snus; 파우치 추적=pouch tracking; no 퀴트진 transliteration.",
    "zh-Hans": "CN: 戒瘾/追踪 native; 尼古丁袋 product term.",
    "zh-Hant": "TW: same native structure as Hans.",
    "hi": "IN-hi: स्नूस छोड़ें native quit; पाउच ट्रैकर pouch intent.",
    "bn-BD": "BN: স্নাস ছাড়ুন native quit.",
    "ta-IN": "TA: ஸ்னூஸ் விடு native quit.",
    "te-IN": "TE: స్నూస్ వదులు native quit.",
    "mr-IN": "MR: स्नूस सोडा native quit.",
    "gu-IN": "GU: સ્નસ છોડો native quit.",
    "kn-IN": "KN: ಸ್ನೂಸ್ ಬಿಡಿ native quit.",
    "ml-IN": "ML: സ്നൂസ് നിർത്തുക native quit.",
    "pa-IN": "PA: ਸਨੂਸ ਛੱਡੋ native quit.",
    "or-IN": "OR: ସ୍ନସ ଛାଡ଼ native quit.",
    "ur-PK": "UR: سنوس چھوڑیں native quit.",
}


def merge_pool(loc: str, pool: tuple[str, ...]) -> tuple[str, ...]:
    extras = ("zyn", "velo", "snus", "vape", "nicotine", "pouch", "stop", "streak", "puff", "tobacco", "withdrawal")
    seen: set[str] = set()
    out: list[str] = []
    for t in (*pool, *extras):
        k = t.strip().lower()
        if k and k not in seen:
            seen.add(k)
            out.append(t)
    return tuple(out)


def emit_locale_aso() -> str:
    lines = ["LOCALE_ASO: dict[str, LocaleASO] = {"]
    errors: list[str] = []

    for loc in sorted(LOCALE_ASO):
        spec = LOCALE_ASO[loc]
        title = NATIVE_TITLES.get(loc)
        if not title:
            errors.append(f"missing title for {loc}")
            continue
        subtitle = NATIVE_SUBTITLES.get(loc, spec.subtitle)
        pool = EN_KEYWORDS if loc.startswith("en-") else merge_pool(loc, spec.keyword_pool)
        kw = pack_keywords(title, subtitle, pool)

        errs = validate_title_subtitle(loc, title, subtitle)
        errs += validate_packed_keywords(loc, kw)
        ol = title_subtitle_overlap(title, subtitle)
        if ol:
            errs.append(f"overlap {ol}")
        if errs:
            errors.append(f"{loc}: {errs}")
            continue

        rationale = (
            f"Native quit title ({title.split(':')[0].split('–')[0].strip()[:20]}…); "
            f"no English Quit. {spec.rationale[:80]}"
        )
        proof_tail = spec.astro_proof if isinstance(spec.astro_proof, tuple) else (str(spec.astro_proof),)
        proof = (VERIFICATION.get(loc, spec.rationale),) + proof_tail[:2]

        lines.append(f'    "{loc}": LocaleASO(')
        lines.append(f"        {title!r},")
        lines.append(f"        {subtitle!r},")
        pool_lines = ", ".join(repr(p) for p in pool)
        if len(pool_lines) > 70:
            lines.append("        (")
            for p in pool:
                lines.append(f"         {p!r},")
            lines.append("        ),")
        else:
            lines.append(f"        ({pool_lines}),")
        lines.append(f"        {rationale!r},")
        plines = ", ".join(repr(p) for p in proof)
        lines.append(f"        ({plines}),")
        if spec.store != "us":
            lines.append(f"        store={spec.store!r},")
        lines.append("    ),")

    lines.append("}")
    if errors:
        print("ERRORS:")
        for e in errors:
            print(e)
        raise SystemExit(1)
    return "\n".join(lines)


def main() -> int:
    path = SCRIPTS / "locale_aso_spec.py"
    text = path.read_text(encoding="utf-8")
    new_block = emit_locale_aso()
    text = re.sub(
        r"LOCALE_ASO: dict\[str, LocaleASO\] = \{.*\n\}",
        new_block,
        text,
        count=1,
        flags=re.S,
    )
    path.write_text(text, encoding="utf-8")
    print("Updated locale_aso_spec.py with native titles for 50 locales")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
