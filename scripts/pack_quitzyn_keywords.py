#!/usr/bin/env python3
"""Pack App Store keyword fields to ~100 chars without title/subtitle overlap."""
from __future__ import annotations

import re
from typing import Iterable


def indexed_terms(name: str, subtitle: str) -> set[str]:
    text = f"{name} {subtitle}".lower()
    terms: set[str] = set()
    for w in re.findall(r"[a-z0-9\u0080-\uffff]+", text, flags=re.I):
        if len(w) >= 2:
            terms.add(w)
    return terms


def _overlaps_indexed(kw: str, indexed: set[str]) -> bool:
    if kw in indexed:
        return True
    for t in indexed:
        if len(kw) >= 4 and (kw in t or t in kw):
            return True
    return False


def pack_keywords(
    name: str,
    subtitle: str,
    candidates: Iterable[str],
    *,
    limit: int = 100,
) -> str:
    """Greedy pack: highest-priority candidates first, skip title overlap."""
    indexed = indexed_terms(name, subtitle)
    kept: list[str] = []
    used = 0
    seen: set[str] = set()

    for raw in candidates:
        kw = raw.strip().lower().replace(" ", "")
        if not kw or kw in seen or _overlaps_indexed(kw, indexed):
            continue
        add = len(kw) + (1 if kept else 0)
        if used + add > limit:
            continue
        kept.append(kw)
        seen.add(kw)
        used += add

    # Second pass: try shorter leftovers to fill slack
    if used < limit - 4:
        for raw in candidates:
            kw = raw.strip().lower().replace(" ", "")
            if not kw or kw in seen or _overlaps_indexed(kw, indexed):
                continue
            add = len(kw) + (1 if kept else 0)
            if used + add <= limit:
                kept.append(kw)
                seen.add(kw)
                used += add

    return ",".join(kept)


# US-market brand/filler terms — must never appear in non-English keyword fields.
ENGLISH_ONLY_TERMS = frozenset(
    {
        "rogue", "cope", "zone", "buzz", "dip", "oral", "craving", "recovery", "quitting",
        "grinds", "upperdecky", "stopsmoking", "habits", "abstain", "zyns", "snusless",
        "pouched", "nicotinefree", "dayssince", "smokefree", "on", "alp", "fre", "lucy",
    }
)

# Latin product names searched internationally; OK outside en-* when relevant.
INTL_PRODUCT_NAMES = frozenset({"snus", "velo", "zyn", "vape"})


def validate_packed_keywords(locale: str, keywords: str) -> list[str]:
    """Fail fast if US English filler leaked into a non-English storefront."""
    if locale.startswith("en-"):
        return []
    errors: list[str] = []
    for term in keywords.split(","):
        t = term.strip().lower()
        if t in ENGLISH_ONLY_TERMS:
            errors.append(f"{locale}: English-only term {t!r} in keywords")
    return errors


def title_subtitle_overlap(name: str, subtitle: str) -> list[str]:
    """Words or substrings (≥4 chars) shared between title and subtitle waste index space."""
    nw = [w.lower() for w in re.findall(r"[a-z0-9\u0080-\uffff]+", name, flags=re.I) if len(w) >= 2]
    sw = [w.lower() for w in re.findall(r"[a-z0-9\u0080-\uffff]+", subtitle, flags=re.I) if len(w) >= 2]
    hits: set[str] = set(nw) & set(sw)
    for a in nw:
        for b in sw:
            if len(a) >= 4 and len(b) >= 4 and (a in b or b in a):
                hits.add(a if a in b or len(a) <= len(b) else b)
    return sorted(hits)


def validate_title_subtitle(locale: str, name: str, subtitle: str) -> list[str]:
    errs: list[str] = []
    for label, val, lim in [("title", name, 30), ("subtitle", subtitle, 30)]:
        if len(val) > lim:
            errs.append(f"{locale}: {label} {len(val)}>{lim}: {val!r}")
    overlap = title_subtitle_overlap(name, subtitle)
    if overlap:
        errs.append(f"{locale}: title/subtitle overlap {overlap}: {name!r} | {subtitle!r}")
    return errs


# US Astro-backed pools for quit zyn / zyn tracker / quit snus / pouch tracker intent.
# Validated via competitor extracts on those seeds (not generic habit/fitness SERPs).
# Title already indexes: quit, zyn, pouch, snus, tracker, nicotine, free, day, counter.
# Excluded: habits/habit (fitness), stopsmoking/smokefree (cigarette SERP; "free" overlaps subtitle),
# upperdecky/grinds/on!/alp/fre/lucy (obscure or off-intent brands).
US_EN_CANDIDATES = [
    "velo",       # 46 — pouch orbit (zyn tracker competitors)
    "buzz",       # 54
    "zone",       # 25 — Zyn competitor brand
    "tobacco",    # 16 — quit snus / chew tobacco combos
    "dip",        # 20 — quit dip
    "chew",       # 13 — quit chewing tobacco
    "oral",       # 7 — oral nicotine
    "rogue",      # 9 — pouch brand in category SERPs
    "cope",       # 9 — dip/pouch adjacent
    "stop",       # 49 — quit snus extract (stop + title quit)
    "streak",     # 6 — day-streak mechanic
    "recovery",   # 6 — health timeline + quit snus extract
    "craving",    # 5 — quit nicotine intent
    "puff",       # 6 — puff count / vape crossover
    "withdrawal", # 5 — quit journey
    "vape",       # 5 — quit vaping crossover
    "plan",       # 43 — quit plan combos (quit snus extract)
]

# Per-locale pools: native quit/pouch terms first; only intl. product names (snus, velo).
# US Astro brand filler (rogue, cope, zone, buzz, dip…) belongs in en-* pools only.
LOCALE_POOLS: dict[str, list[str]] = {
    "en-US": US_EN_CANDIDATES,
    "en-GB": US_EN_CANDIDATES,
    "en-AU": US_EN_CANDIDATES,
    "en-CA": US_EN_CANDIDATES,
    "de-DE": [
        "beutel", "velo", "tabak", "dampfen", "kauen", "entzug", "gewohnheit", "serie",
        "tagebuch", "aufhören", "verlangen", "kalender", "garten", "gesundheit", "privat",
        "abhängigkeit", "rückfall", "nikotinfrei", "rauchfrei", "snus",
    ],
    "fr-FR": [
        "sachet", "tabac", "vapotage", "sevrage", "envie", "habitude", "journal", "arrêter",
        "série", "snus", "velo", "dépendance", "abstinence", "récupération", "chiquer",
        "calendrier", "jardin", "santé", "privé", "sansfumée", "rechute",
    ],
    "fr-CA": [
        "sachet", "tabac", "vapotage", "sevrage", "envie", "habitude", "journal", "arrêter",
        "série", "snus", "velo", "dépendance", "abstinence", "récupération", "chiquer",
        "calendrier", "jardin", "santé", "privé", "cessation", "rechute",
    ],
    "es-ES": [
        "bolsitas", "tabaco", "vapeo", "dejar", "adicción", "antojo", "abstinencia",
        "recuperación", "habito", "diario", "serie", "snus", "velo", "dependencia",
        "calendario", "jardín", "salud", "privado", "masticar", "recaída",
    ],
    "es-MX": [
        "bolsitas", "tabaco", "vapeo", "dejar", "adicción", "antojo", "abstinencia",
        "recuperación", "habito", "diario", "serie", "snus", "velo", "dependencia",
        "calendario", "jardín", "salud", "privado", "masticar", "recaída",
    ],
    "it": [
        "bustine", "tabacco", "svapo", "smettere", "dipendenza", "astinenza", "diario",
        "serie", "snus", "velo", "calendario", "giardino", "salute", "privato", "voglia",
        "masticare", "ricaduta",
    ],
    "pt-BR": [
        "saquinhos", "tabaco", "vape", "parar", "dependência", "abstinência", "recuperação",
        "diário", "serie", "snus", "velo", "calendário", "jardim", "saúde", "privado",
        "vontade", "mastigar", "recaída",
    ],
    "pt-PT": [
        "saquinhos", "tabaco", "vape", "parar", "dependência", "abstinência", "recuperação",
        "diário", "serie", "snus", "velo", "calendário", "jardim", "saúde", "privado",
        "vontade", "mastigar", "recaída",
    ],
    "nl-NL": [
        "zakjes", "snus", "velo", "tabak", "dampen", "stoppen", "verslaving", "ontwenning",
        "gewoonte", "dagboek", "serie", "kalender", "tuin", "gezondheid", "privé",
        "verlangen", "terugval", "kauwen",
    ],
    "pl": [
        "saszetki", "snus", "velo", "tytoń", "vape", "przestać", "uzależnienie", "odwyk",
        "nawyk", "dziennik", "seria", "kalendarz", "ogród", "zdrowie", "prywatny",
        "głód", "nawrót", "żuć",
    ],
    "sv": [
        "prillor", "snus", "velo", "tobak", "vape", "sluta", "beroende", "abstinens",
        "vana", "dagbok", "serie", "kalender", "trädgård", "hälsa", "privat", "sug",
        "återfall", "tugga",
    ],
    "da": [
        "poser", "snus", "velo", "tobak", "vape", "stoppe", "afhængighed", "abstinens",
        "vane", "dagbog", "serie", "kalender", "have", "sundhed", "privat", "trang",
        "tilbagefald", "tygge",
    ],
    "no": [
        "poser", "snus", "velo", "tobakk", "vape", "slutte", "avhengighet", "avholdenhet",
        "vanedagbok", "serie", "kalender", "hage", "helse", "privat", "sug", "tilbakefall",
        "tygge",
    ],
    "fi": [
        "nauhat", "snus", "velo", "tupakka", "vape", "lopettaa", "riippuvuus", "tottumus",
        "päiväkirja", "sarja", "kalenteri", "puutarha", "terveys", "yksityinen", "himo",
        "uusiutuminen", "pureskella",
    ],
    "cs": [
        "sáčky", "snus", "velo", "tabák", "vape", "přestat", "závislost", "abstinence",
        "zvyk", "deník", "série", "kalendář", "zahrada", "zdraví", "soukromí", "chuť",
        "relaps", "žvýkat",
    ],
    "sk": [
        "vrecká", "snus", "velo", "tabak", "vape", "prestať", "závislosť", "abstinencia",
        "zvyk", "denník", "séria", "kalendár", "záhrada", "zdravie", "súkromie", "chuť",
        "relaps", "žuť",
    ],
    "hu": [
        "tasak", "snus", "velo", "dohány", "vape", "abbahagy", "függőség", "elvonás",
        "szokás", "napló", "sorozat", "naptár", "kert", "egészség", "privát", "vágy",
        "visszaesés", "rágás",
    ],
    "ro": [
        "plicuri", "snus", "velo", "tutun", "vape", "opri", "dependență", "abstinență",
        "obicei", "jurnal", "serie", "calendar", "grădină", "sănătate", "privat", "poftă",
        "recădere", "mesteca",
    ],
    "hr": [
        "vrećice", "snus", "velo", "duhan", "vape", "prestati", "ovisnost", "apstinencija",
        "navika", "dnevnik", "niz", "kalendar", "vrt", "zdravlje", "privatno", "želja",
        "recidiv", "žvakati",
    ],
    "sl-SI": [
        "vrečke", "snus", "velo", "tobak", "vape", "nehati", "odvisnost", "abstinenca",
        "navada", "dnevnik", "niz", "koledar", "vrt", "zdravje", "zasebno", "želja",
        "ponovitev", "žvečiti",
    ],
    "el": [
        "φακελάκια", "snus", "velo", "καπνός", "ηλεκτρονικό", "διακοπή", "εξάρτηση", "αποχή",
        "συνήθεια", "ημερολόγιο", "σειρά", "κήπος", "υγεία", "ιδιωτικό",
        "λαχτάρα", "υποτροπή", "μάσηση",
    ],
    "tr": [
        "poşet", "snus", "velo", "tütün", "vape", "bırakmak", "bağımlılık", "ayıklık",
        "alışkanlık", "günlük", "dizi", "takvim", "bahçe", "sağlık", "özel", "istek",
        "nüks", "çiğneme",
    ],
    "ru": [
        "пакетики", "snus", "velo", "табак", "вейп", "бросить", "зависимость", "воздержание",
        "привычка", "дневник", "серия", "календарь", "сад", "здоровье", "приватный",
        "тяга", "срыв", "жевать",
    ],
    "uk": [
        "пакетики", "snus", "velo", "тютюн", "вейп", "кинути", "залежність", "утримання",
        "звичка", "щоденник", "серія", "календар", "сад", "здоров'я", "приватний", "тяга",
        "зрив", "жувати",
    ],
    "ca": [
        "bosses", "snus", "velo", "tabac", "vape", "deixar", "addicció", "abstinència",
        "recuperació", "hàbit", "diari", "sèrie", "calendari", "jardí", "salut", "privat",
        "gana", "recaiguda", "mastegar",
    ],
    "ja": [
        "ポーチ", "スヌース", "ベイプ", "禁煙", "ニコチン", "依存", "離脱", "渇望", "習慣", "日記",
        "連続", "記録", "カウンター", "カレンダー", "ウィジェット", "庭", "健康", "非公開", "再発",
    ],
    "ko": [
        "파우치", "스누스", "베이프", "금연", "니코틴", "중독", "절제", "갈망", "습관", "일기",
        "연속", "기록", "카운터", "캘린더", "위젯", "정원", "건강", "비공개", "재발",
    ],
    "zh-Hans": [
        "尼古丁袋", "唇烟", "电子烟", "戒烟", "戒断", "渴望", "习惯", "日记", "连续", "记录",
        "计数器", "日历", "小组件", "花园", "健康", "私密", "复吸", "咀嚼",
    ],
    "zh-Hant": [
        "尼古丁袋", "唇煙", "電子煙", "戒菸", "戒斷", "渴望", "習慣", "日記", "連續", "記錄",
        "計數器", "日曆", "小工具", "花園", "健康", "私密", "復吸", "咀嚼",
    ],
    "ar-SA": [
        "أكياس", "فيب", "إقلاع", "إدمان", "امتناع", "عادة", "يوميات", "سلسلة", "تبغ", "تقويم",
        "حديقة", "صحة", "خاص", "انتكاسة", "snus", "velo",
    ],
    "he": [
        "שקיות", "וייפ", "הפסקה", "התמכרות", "התנזרות", "הרגל", "יומן", "רצף", "טבק", "לוחשנה",
        "גן", "בריאות", "פרטי", "מחזור", "snus", "velo",
    ],
    "hi": [
        "पाउच", "वेप", "छोड़ना", "लत", "संयम", "आदत", "डायरी", "स्ट्रीक", "तंबाकू", "कैलेंडर",
        "बगीचा", "स्वास्थ्य", "निजी", "पुनरावृत्ति", "snus", "velo",
    ],
    "bn-BD": [
        "পাউচ", "ভেপ", "ছাড়া", "আসক্তি", "সংযম", "অভ্যাস", "ডায়েরি", "ধারা", "তামাক", "ক্যালেন্ডার",
        "বাগান", "স্বাস্থ্য", "ব্যক্তিগত", "পুনরায়", "snus", "velo",
    ],
    "gu-IN": [
        "પાઉચ", "વેપ", "છોડવું", "વ્યસન", "સંયમ", "આદત", "ડાયરી", "શ્રેણી", "તમાકુ", "કેલેન્ડર",
        "બગીચો", "આરોગ્ય", "ખાનગી", "પુનરાવૃત્તિ", "snus", "velo",
    ],
    "kn-IN": [
        "ಪಾಉಚ್", "ವೇಪ್", "ಬಿಡುವುದು", "ಚಟ", "ಸಂಯಮ", "ಅಭ್ಯಾಸ", "ಡೈರಿ", "ಸರಣಿ", "ಹೊಗೆತಂಬಾಕು", "ಕ್ಯಾಲೆಂಡರ್",
        "ತೋಟ", "ಆರೋಗ್ಯ", "ಖಾಸಗಿ", "ಮರುಕಳಿಸುವಿಕೆ", "snus", "velo",
    ],
    "ml-IN": [
        "പൗച്ച്", "വേപ്പ്", "നിർത്തൽ", "ആസക്തി", "വർജനം", "ശീലം", "ഡയറി", "സീരീസ്", "പുകയില", "കലണ്ടർ",
        "തോട്ടം", "ആരോഗ്യം", "സ്വകാര്യം", "പുനരാവർത്തനം", "snus", "velo",
    ],
    "mr-IN": [
        "पाउच", "वेप", "सोडणे", "व्यसन", "संयम", "सवय", "डायरी", "मालिका", "तंबाखू", "दिनदर्शिका",
        "बाग", "आरोग्य", "खाजगी", "पुन्हा", "snus", "velo",
    ],
    "or-IN": [
        "ପାଉଚ", "ଭେପ", "ଛାଡିବା", "ଆସକ୍ତି", "ବିରତି", "ଅଭ୍ୟାସ", "ଡାଇରୀ", "ଧାରା", "ତମାଖୁ", "କ୍ୟାଲେଣ୍ଡର",
        "ବଗିଚା", "ସ୍ୱାସ୍ଥ୍ୟ", "ବ୍ୟକ୍ତିଗତ", "ପୁନରାବୃତ୍ତି", "snus", "velo",
    ],
    "pa-IN": [
        "ਪਾਊਚ", "ਵੇਪ", "ਛੱਡਣਾ", "ਆਦੀ", "ਸੰਜਮ", "ਆਦਤ", "ਡਾਇਰੀ", "ਲੜੀ", "ਤਮਾਕੂ", "ਕੈਲੰਡਰ",
        "ਬਾਗ", "ਸਿਹਤ", "ਨਿੱਜੀ", "ਦੁਬਾਰਾ", "snus", "velo",
    ],
    "ta-IN": [
        "பவுச்", "வேப்", "விடுவது", "அடிமை", "தவிர்ப்பு", "பழக்கம்", "டைரி", "தொடர்", "புகையிலை", "நாட்காட்டி",
        "தோட்டம்", "ஆரோக்கியம்", "தனிப்பட்ட", "மீண்டும்", "snus", "velo",
    ],
    "te-IN": [
        "పౌచ్", "వేప్", "వదలడం", "వ్యసనం", "సంయమం", "అలవాటు", "డైరీ", "సిరీస్", "పొగాకు", "క్యాలెండర్",
        "తోట", "ఆరోగ్యం", "ప్రైవేట్", "మళ్లీ", "snus", "velo",
    ],
    "ur-PK": [
        "پاؤچ", "ویپ", "چھوڑنا", "نشہ", "پرہیز", "عادت", "ڈائری", "سلسلہ", "تمباکو", "کیلنڈر",
        "باغ", "صحت", "نجی", "دوبارہ", "snus", "velo",
    ],
    "th": [
        "ซอง", "วีป", "เลิก", "ติด", "งด", "นิสัย", "ไดอารี่", "สตรีค", "ยาสูบ", "ปฏิทิน",
        "สวน", "สุขภาพ", "ส่วนตัว", "กลับมา", "snus", "velo",
    ],
    "vi": [
        "túi", "vape", "cai", "nghiện", "kiêng", "thóiquen", "nhậtký", "chuỗi", "thuốc", "lich",
        "vuon", "suckhoe", "riengtu", "talai", "snus", "velo",
    ],
    "id": [
        "kantong", "vape", "berhenti", "kecanduan", "pantang", "kebiasaan", "diari", "rangkai",
        "tembakau", "kalender", "taman", "kesehatan", "pribadi", "kambuh", "snus", "velo",
    ],
    "ms": [
        "kantung", "vape", "berhenti", "ketagihan", "pantang", "tabiat", "diari", "rangkai",
        "tembakau", "kalendar", "taman", "kesihatan", "peribadi", "kambuh", "snus", "velo",
    ],
}

# Title/subtitle pairs with zero overlapping index terms (≤30 chars each).
# Title = pouch/snus product; subtitle = day counter & garden (or nicotine-free once).
TITLE_UPDATES: dict[str, tuple[str, str]] = {
    "ar-SA": ("كيت زين – أكياس وسنوس", "عداد الأيام والحديقة"),
    "bn-BD": ("কুইট জিন – পাউচ ট্র্যাকার", "দিন গণনা ও বাগান"),
    "ca": ("Quit Zyn: Bosses & snus", "Comptador dies & jardí"),
    "cs": ("Quit Zyn – Sáčky & snus", "Počítadlo dnů & zahrada"),
    "da": ("Quit Zyn: Snus & poser", "Dagtæller & have"),
    "de-DE": ("Quit Zyn: Snus & Beutel", "Nikotinfrei Tage & Garten"),
    "el": ("Quit Zyn – Φακελάκια & snus", "Μετρητής ημερών & κήπος"),
    "es-ES": ("Quit Zyn: Bolsas & snus", "Contador días & jardín"),
    "es-MX": ("Quit Zyn: Bolsas & snus", "Contador días & jardín"),
    "fi": ("Quit Zyn – Pussit & snus", "Päivälaskuri & puutarha"),
    "fr-FR": ("Quit Zyn: Sachets & snus", "Compteur jours & jardin"),
    "fr-CA": ("Quit Zyn: Sachets & snus", "Compteur jours & jardin"),
    "gu-IN": ("ક્વિટ ઝિન – પાઉચ ટ્રેકર", "દિવસ ગણતરી અને બગીચો"),
    "he": ("קוויט זין – שקיות וסנוס", "מונה ימים וגן"),
    "hi": ("क्विट ज़िन – पाउच ट्रैकर", "दिन गिनती और बगीचा"),
    "hr": ("Quit Zyn – Vrećice & snus", "Brojač dana & vrt"),
    "hu": ("Quit Zyn – Tasakok & snus", "Napszámító & kert"),
    "id": ("Quit Zyn – Kantong & snus", "Hitung hari & taman"),
    "it": ("Quit Zyn: Bustine & snus", "Contatore giorni & giardino"),
    "ja": ("クィットザン－ポーチ&スヌース", "禁煙日数カウンター&庭"),
    "kn-IN": ("ಕ್ವಿಟ್ ಜಿನ್ – ಪಾಉಚ್ ಟ್ರ್ಯಾಕರ್", "ದಿನಗಳ ಎಣಿಕೆ ಮತ್ತು ತೋಟ"),
    "ko": ("퀴트 진 – 파우치 & 스누스", "금연 일수 & 정원"),
    "mr-IN": ("क्विट झिन – पाउच ट्रॅकर", "दिवस मोजणी आणि बाग"),
    "ms": ("Quit Zyn – Kantung & snus", "Kira hari & taman"),
    "no": ("Quit Zyn: Snus & poser", "Dagteller & hage"),
    "or-IN": ("କ୍ୱିଟ ଜିନ – ପାଉଚ ଟ୍ରାକର", "ଦିନ ଗଣନା ଏବଂ ବଗିଚା"),
    "pa-IN": ("ਕਵਿਟ ਜ਼ਿਨ – ਪਾਊਚ ਟ੍ਰੈਕਰ", "ਦਿਨ ਗਿਣਤੀ ਅਤੇ ਬਾਗ"),
    "pl": ("Quit Zyn – Saszetki & snus", "Licznik dni & ogród"),
    "pt-BR": ("Quit Zyn – Saquinhos & snus", "Contador dias & jardim"),
    "pt-PT": ("Quit Zyn – Saquinhos & snus", "Contador dias & jardim"),
    "ro": ("Quit Zyn – Plicuri & snus", "Contor zile & grădină"),
    "ru": ("Quit Zyn – Пакетики & snus", "Счётчик дней & сад"),
    "sk": ("Quit Zyn – Vrecká & snus", "Počítadlo dní & záhrada"),
    "sl-SI": ("Quit Zyn – Vrečke & snus", "Števec dni & vrt"),
    "sv": ("Quit Zyn: Snus & prillor", "Dagräknare & trädgård"),
    "te-IN": ("క్విట్ జిన్ – పౌచ్ ట్రాకర్", "రోజుల లెక్క & తోట"),
    "th": ("ควิตซิน – ถุงนิโคติน", "นับวัน & สวน"),
    "tr": ("Quit Zyn – Poşet & snus", "Gün sayacı & bahçe"),
    "uk": ("Quit Zyn – Пакетики & snus", "Лічильник днів & сад"),
    "ur-PK": ("کوئٹ زِن – پاؤچ ٹریکر", "دن گنتی اور باغ"),
    "vi": ("Quit Zyn – Túi & snus", "Đếm ngày & vườn"),
    "zh-Hans": ("戒瘾助手-尼古丁袋追踪", "无烟碱日计数&花园"),
    "zh-Hant": ("戒癮助手-尼古丁袋追蹤", "無菸鹼日計數&花園"),
}
