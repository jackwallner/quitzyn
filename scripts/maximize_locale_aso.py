#!/usr/bin/env python3
"""Apply title/subtitle maximization + keyword pool fill, rewrite locale_aso_spec."""
from __future__ import annotations

import re
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))

from locale_aso_spec import LOCALE_ASO, EN_KEYWORDS, EN_TITLE, EN_PROOF  # noqa: E402
from pack_quitzyn_keywords import pack_keywords, validate_title_subtitle  # noqa: E402

# Meaningful subtitle/title expansions (validated ≤30, zero overlap)
TITLE_SUBTITLE: dict[str, tuple[str, str]] = {
    "en-US": ("Quit Zyn: Pouch & Snus Tracker", "Nicotine Free Days & Garden"),
    "en-GB": ("Quit Zyn: Pouch & Snus Tracker", "Nicotine Free Days & Garden"),
    "en-CA": ("Quit Zyn: Pouch & Snus Tracker", "Nicotine Free Days & Garden"),
    "en-AU": ("Quit Zyn: Pouch & Snus Tracker", "Nicotine Free Days & Garden"),
    "de-DE": ("Quit Zyn: Snus & Beutel", "Nikotinfreie Tage & Garten"),
    "da": ("Quit Zyn: Snus & poser", "Nikotinfri dagtæller & have"),
    "no": ("Quit Zyn: Snus & poser", "Nikotinfri dagteller & hage"),
    "fr-FR": ("Quit Zyn: Sachets & snus", "Compteur de jours & jardin"),
    "fr-CA": ("Quit Zyn: Sachets & snus", "Compteur de jours & jardin"),
    "es-ES": ("Quit Zyn: Bolsas & snus", "Contador de días & jardín"),
    "es-MX": ("Quit Zyn: Bolsas & snus", "Contador de días & jardín"),
    "it": ("Quit Zyn: Bustine & snus", "Contatore giorni & giardino"),
    "pt-BR": ("Quit Zyn: Saquinhos & snus", "Contador de dias & jardim"),
    "pt-PT": ("Quit Zyn: Saquinhos & snus", "Contador de dias & jardim"),
    "vi": ("Quit Zyn: Túi & snus", "Đếm ngày không nicotine"),
    "th": ("Quit Zyn: ถุงนิโคติน & snus", "นับวันเลิกนิโคติน & สวน"),
    "he": ("קוויט זין – שקיות וסנוס", "מונה ימים ללא ניקוטין"),
    "ar-SA": ("كيت زين – أكياس وسنوس", "عداد أيام خالية من النيكوتين"),
    "ja": ("クィットザン｜ポーチ&スヌース追跡", "禁煙日数カウンター&庭園"),
    "ko": ("퀴트진｜파우치&스누스 추적", "금연 일수 카운터&정원"),
    "zh-Hans": ("戒瘾助手｜尼古丁袋追踪器", "无烟碱日计数&虚拟花园"),
    "zh-Hant": ("戒癮助手｜尼古丁袋追蹤器", "無菸鹼日計數&虛擬花園"),
    "ta-IN": ("க்விட் ஸின் – பவுச் டிராக்கர்", "நாட்கள் எண்ணிக்கை & தோட்டம்"),
}

# Latin loanwords safe outside en-* (not on ENGLISH_ONLY blocklist)
INTL_FILL: tuple[str, ...] = (
    "zyn", "nicotine", "puff", "stop", "streak", "tobacco", "withdrawal",
)

# Per-locale extra pool terms for keyword fill
EXTRA_POOL: dict[str, tuple[str, ...]] = {
    "es-MX": ("stop", "puff", "tobacco", "withdrawal", "calendario", "salud", "privado"),
    "es-ES": ("salud", "masticar", "privado", "calendario"),
    "fr-FR": ("chiquer", "rechute", "calendrier", "privé", "santé"),
    "fr-CA": ("chiquer", "cessation", "calendrier", "privé", "santé"),
    "de-DE": ("dampfen", "snus", "privat", "kalender"),
    "nl-NL": ("verlangen", "kauwen", "privé"),
    "da": ("tilbagefald", "tygge"),
    "no": ("tilbakefall", "tygge"),
    "fi": ("pureskella", "yksityinen"),
    "it": ("masticare", "ricaduta", "voglia"),
    "pt-BR": ("vontade", "recaída", "privado"),
    "pt-PT": ("vontade", "recaída", "privado"),
    "ca": ("gana", "privat"),
    "hr": ("žvakati", "privatno"),
    "ro": ("recădere",),
    "pl": ("żuć", "prywatny"),
    "tr": ("çiğneme", "özel", "nüks"),
    "vi": ("talai", "snus", "pouch", "nicotine"),
    "id": ("kambuh", "snus", "pribadi"),
    "ms": ("kambuh", "snus", "peribadi", "nicotine"),
    "th": ("กลับมา", "snus", "nicotine", "pouch"),
    "ar-SA": ("snus", "zyn", "nicotine", "pouch", "حديقة"),
    "he": ("snus", "zyn", "nicotine", "pouch", "פרטי"),
    "ja": ("velo", "snus", "zyn", "puff", "stop", "streak", "tobacco", "vape"),
    "ko": ("velo", "snus", "zyn", "puff", "stop", "streak", "tobacco", "vape", "nicotine"),
    "zh-Hans": ("velo", "snus", "zyn", "puff", "stop", "streak", "vape", "nicotine"),
    "zh-Hant": ("velo", "snus", "zyn", "puff", "stop", "streak", "vape", "nicotine"),
    "hi": ("zyn", "nicotine", "puff", "stop", "streak", "tobacco"),
    "bn-BD": ("zyn", "nicotine", "puff", "stop", "streak"),
    "ta-IN": ("zyn", "nicotine", "puff", "stop", "streak"),
    "te-IN": ("zyn", "nicotine", "puff", "stop", "streak"),
    "mr-IN": ("zyn", "nicotine", "puff", "stop", "streak"),
    "gu-IN": ("zyn", "nicotine", "puff", "stop", "streak"),
    "kn-IN": ("zyn", "nicotine", "puff", "stop", "streak"),
    "ml-IN": ("zyn", "nicotine", "puff", "stop", "streak"),
    "pa-IN": ("zyn", "nicotine", "puff", "stop", "streak"),
    "or-IN": ("zyn", "nicotine", "puff", "stop", "streak"),
    "ur-PK": ("zyn", "nicotine", "puff", "stop", "streak"),
}

EN_KEYWORDS_NEW: tuple[str, ...] = EN_KEYWORDS + ("plan",)


def merge_pool(loc: str, pool: tuple[str, ...]) -> tuple[str, ...]:
    seen: set[str] = set()
    out: list[str] = []
    extras = list(EXTRA_POOL.get(loc, ())) + list(INTL_FILL)
    for t in (*pool, *extras):
        k = t.strip().lower()
        if k and k not in seen:
            seen.add(k)
            out.append(t)
    return tuple(out)


def main() -> int:
    path = SCRIPTS / "locale_aso_spec.py"
    text = path.read_text(encoding="utf-8")

    # Update EN_KEYWORDS line
    text = re.sub(
        r'EN_KEYWORDS: tuple\[str, \.\.\.\] = \([^)]+\)',
        f"EN_KEYWORDS: tuple[str, ...] = {repr(EN_KEYWORDS_NEW)}",
        text,
        count=1,
    )

    for loc, spec in LOCALE_ASO.items():
        title, subtitle = TITLE_SUBTITLE.get(loc, (spec.title, spec.subtitle))
        errs = validate_title_subtitle(loc, title, subtitle)
        if errs:
            print(f"SKIP {loc}: {errs}")
            continue
        pool = merge_pool(loc, spec.keyword_pool)
        if loc.startswith("en-"):
            pool = EN_KEYWORDS_NEW
        kw = pack_keywords(title, subtitle, pool)
        print(f"{loc}: T{len(title)} S{len(subtitle)} K{len(kw)}")

    print("\nPatch locale_aso_spec.py manually via optimize after updating spec entries...")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
