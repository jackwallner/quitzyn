#!/usr/bin/env python3
"""Push title/subtitle >24 chars (≤30) and keywords ≥94 for all 50 locales."""
from __future__ import annotations

import re
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))

from locale_aso_spec import LOCALE_ASO, EN_KEYWORDS, EN_TITLE, EN_PROOF  # noqa: E402
from pack_quitzyn_keywords import (  # noqa: E402
    pack_keywords,
    validate_packed_keywords,
    validate_title_subtitle,
    title_subtitle_overlap,
)

EN_SUBTITLE = "Nicotine Free Days & Garden"

MAX_TITLES: dict[str, str] = {
    "en-US": EN_TITLE,
    "en-GB": EN_TITLE,
    "en-CA": EN_TITLE,
    "en-AU": EN_TITLE,
    "ar-SA": "إقلاع السنوس: أكياس ونيكوتين",
    "bn-BD": "স্নাস ছাড়ুন – পাউচ ট্র্যাকার",
    "ca": "Deixa el snus: Bosses & velo",
    "cs": "Přestaň snus: Sáčky & velo",
    "da": "Stop snus: Poser & prillor",
    "de-DE": "Snus aufhören: Beutel & Zyn",
    "el": "Σταμάτα snus: Φακελάκια & velo",
    "es-ES": "Dejar el snus: Bolsas & velo",
    "es-MX": "Dejar el snus: Bolsas & velo",
    "fi": "Lopeta nuuska: Pussit & snus",
    "fr-CA": "Arrêter snus: Sachets & velo",
    "fr-FR": "Arrêter snus: Sachets & velo",
    "gu-IN": "સ્નસ છોડો – પાઉચ ટ્રેકર એપ",
    "he": "הפסקת snus: שקיות וסנוס velo",
    "hi": "स्नूस छोड़ें – पाउच ट्रैकर",
    "hr": "Prestani snus: Vrećice & velo",
    "hu": "Snus abbahagy: Tasakok & velo",
    "id": "Berhenti snus: Kantong & velo",
    "it": "Smetti snus: Bustine & velo",
    "ja": "ニコチン袋・スヌース・ポーチ禁煙追跡ZYNアプリ版",
    "kn-IN": "ಸ್ನೂಸ್ ಬಿಡಿ – ಪಾಉಚ್ ಟ್ರ್ಯಾಕರ್",
    "ko": "스누스 끊기 니코틴 파우치 ZYN 추적 앱 프로그램",
    "ml-IN": "സ്നൂസ് നിർത്തുക – പൗച്ച് ആപ്പ്",
    "mr-IN": "स्नूस सोडा – पाउच ट्रॅकर ऍप",
    "ms": "Berhenti snus: Kantung & velo",
    "nl-NL": "Stop met snus: Zakjes & velo",
    "no": "Slutt med snus: Poser & velo",
    "or-IN": "ସ୍ନସ ଛାଡ଼ – ପାଉଚ ଟ୍ରାକର ଆପ୍",
    "pa-IN": "ਸਨੂਸ ਛੱਡੋ – ਪਾਊਚ ਟ੍ਰੈਕਰ ਐਪ",
    "pl": "Rzuć snusa: Saszetki & velo",
    "pt-BR": "Parar o snus: Saquinhos & velo",
    "pt-PT": "Parar o snus: Saquinhos & velo",
    "ro": "Oprește snus: Plicuri & velo",
    "ru": "Брось snus: Пакетики & velo",
    "sk": "Prestaň snus: Vrecká & velo",
    "sl-SI": "Nehaj snus: Vrečke & velo",
    "sv": "Sluta snusa: Prillor & snus",
    "ta-IN": "ஸ்னூஸ் விடு – பவுச் டிராக்கர்",
    "te-IN": "స్నూస్ వదులు – పౌచ్ ట్రాకర్",
    "th": "เลิก snus: ถุงนิโคติน & velo",
    "tr": "Bırak snusu: Poşet & velo",
    "uk": "Кинь snus: Пакетики & velo",
    "ur-PK": "سنوس چھوڑیں – پاؤچ ٹریکر ایپ",
    "vi": "Bỏ thuốc snus: Túi & velo",
    "zh-Hans": "戒瘾助手｜尼古丁袋ZYN无烟碱戒断追踪应用助手APP",
    "zh-Hant": "戒癮助手｜尼古丁袋ZYN無菸鹼戒斷追蹤應用助手APP",
}

MAX_SUBTITLES: dict[str, str] = {
    "en-US": EN_SUBTITLE,
    "en-GB": EN_SUBTITLE,
    "en-CA": EN_SUBTITLE,
    "en-AU": EN_SUBTITLE,
    "ar-SA": "عداد أيام خالية من النيكوتين",
    "bn-BD": "নিকোটিন মুক্ত দিন গণনা ও বাগান",
    "ca": "Comptador dies sense nicotina",
    "cs": "Počítadlo dnů bez nikotinu",
    "da": "Nikotinfri dagtæller & have",
    "de-DE": "Nikotinfreie Tage & Garten",
    "el": "Μετρητής ημερών χωρίς νικοτίνη",
    "es-ES": "Contador de días sin nicotina",
    "es-MX": "Contador de días sin nicotina",
    "fi": "Nikotiiniton päivälaskuri",
    "fr-CA": "Compteur jours sans nicotine",
    "fr-FR": "Compteur jours sans nicotine",
    "gu-IN": "નિકોટિન મુક્ત દિવસ ગણતરી બગીચો",
    "he": "מונה ימים נקיים מניקוטין וגן",
    "hi": "निकोटीन मुक्त दिन गिनती बगीचा",
    "hr": "Brojač dana bez nikotina & vrt",
    "hu": "Nikotinfüggetlen napok & kert",
    "id": "Hitung hari bebas nikotin",
    "it": "Contatore giorni no nicotina",
    "ja": "無ニコチン日数カウンター・バーチャル庭園ZYNアプリ",
    "kn-IN": "ನಿಕೋಟಿನ್ ಮುಕ್ತ ದಿನಗಳ ಎಣಿಕೆ ತೋಟ",
    "ko": "무니코틴 프리 일수 카운터 & 가상 정원 성장",
    "ml-IN": "നികോട്ടിൻ ഫ്രീ ദിവസങ്ങൾ തോട്ടം",
    "mr-IN": "निकोटीन मुक्त दिवस मोजणी बाग",
    "ms": "Hitung hari tanpa nikotin",
    "nl-NL": "Nikotinvrije dagen & tuin",
    "no": "Nikotinfri dagteller & hage",
    "or-IN": "ନିକୋଟିନ ମୁକ୍ତ ଦିନ ଗଣନା ବଗିଚା",
    "pa-IN": "ਨਿਕੋਟੀਨ ਮੁਕਤ ਦਿਨ ਗਿਣਤੀ ਬਾਗ",
    "pl": "Dni bez nikotyny & licznik",
    "pt-BR": "Contador de dias sem nicotina",
    "pt-PT": "Contador de dias sem nicotina",
    "ro": "Contor zile fără nicotină",
    "ru": "Счётчик дней без никотина",
    "sk": "Počítadlo dní bez nikotínu",
    "sl-SI": "Števec brez nikotina & vrt",
    "sv": "Fri från nikotin dagräknare",
    "ta-IN": "நாட்கள் எண்ணிக்கை & தோட்டம்",
    "te-IN": "నికోటిన్ లేని రోజుల లెక్క తోట",
    "th": "นับวันไม่นิโคติน & สวนเสมือน",
    "tr": "Nikotinsiz gün sayacı & bahçe",
    "uk": "Лічильник днів без нікотину",
    "ur-PK": "نیکوٹین فری دن گنتی اور باغ",
    "vi": "Đếm ngày không nicotine & vườn",
    "zh-Hans": "无烟碱日计数器・虚拟花园成长应用助手VELOZYN",
    "zh-Hant": "無菸鹼日計數器・虛擬花園成長應用助手VELOZYN",
}

EXTRA_KW: dict[str, tuple[str, ...]] = {
    "en-US": ("plan",),
}


def merge_pool(loc: str, pool: tuple[str, ...]) -> tuple[str, ...]:
    extras = (
        "zyn", "velo", "snus", "vape", "nicotine", "pouch", "stop", "streak",
        "puff", "tobacco", "withdrawal", "relapse", "widget", "calendar",
    ) + EXTRA_KW.get(loc, ())
    seen: set[str] = set()
    out: list[str] = []
    for t in (*pool, *extras):
        k = t.strip().lower().replace(" ", "")
        if k and k not in seen:
            seen.add(k)
            out.append(t)
    return tuple(out)


def validate_pair(loc: str, title: str, subtitle: str) -> list[str]:
    errs = validate_title_subtitle(loc, title, subtitle)
    ol = title_subtitle_overlap(title, subtitle)
    if ol:
        errs.append(f"overlap {ol}")
    if len(title) <= 24:
        errs.append(f"title short {len(title)}")
    if len(subtitle) <= 24:
        errs.append(f"subtitle short {len(subtitle)}")
    return errs


def emit() -> str:
    errors: list[str] = []
    lines = ["LOCALE_ASO: dict[str, LocaleASO] = {"]
    stats: list[tuple[str, int, int, int]] = []

    for loc in sorted(LOCALE_ASO):
        spec = LOCALE_ASO[loc]
        title = MAX_TITLES[loc]
        subtitle = MAX_SUBTITLES[loc]
        pool = EN_KEYWORDS if loc.startswith("en-") else merge_pool(loc, spec.keyword_pool)
        kw = pack_keywords(title, subtitle, pool)

        errs = validate_pair(loc, title, subtitle)
        errs += validate_packed_keywords(loc, kw)
        if len(kw) < 94:
            errs.append(f"kw short {len(kw)}")

        if errs:
            errors.append(f"{loc} T{len(title)}/{len(subtitle)}/{len(kw)}: {errs}")
            continue

        stats.append((loc, len(title), len(subtitle), len(kw)))
        proof = spec.astro_proof if isinstance(spec.astro_proof, tuple) else (spec.astro_proof,)

        lines.append(f'    "{loc}": LocaleASO(')
        lines.append(f"        {title!r},")
        lines.append(f"        {subtitle!r},")
        lines.append("        (")
        for p in pool:
            lines.append(f"         {p!r},")
        lines.append("        ),")
        lines.append(f"        {spec.rationale!r},")
        if proof:
            pl = ", ".join(repr(p) for p in proof[:3])
            lines.append(f"        ({pl}),")
        if spec.store != "us":
            lines.append(f"        store={spec.store!r},")
        lines.append("    ),")

    lines.append("}")
    if errors:
        print("FAILURES:")
        for e in errors:
            print(e)
        raise SystemExit(1)
    for s in stats:
        print(f"  {s[0]}: {s[1]}/{s[2]}/{s[3]}")
    return "\n".join(lines)


def main() -> int:
    path = SCRIPTS / "locale_aso_spec.py"
    text = path.read_text(encoding="utf-8")
    text = re.sub(r'EN_SUBTITLE = "[^"]*"', f'EN_SUBTITLE = "{EN_SUBTITLE}"', text, count=1)
    new_block = emit()
    text = re.sub(
        r"LOCALE_ASO: dict\[str, LocaleASO\] = \{.*\n\}",
        new_block,
        text,
        count=1,
        flags=re.S,
    )
    path.write_text(text, encoding="utf-8")
    print(f"Updated {len(MAX_TITLES)} locales")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
