#!/usr/bin/env python3
"""Build native descriptions, promotional text, and release notes for all 50 locales.

Adapts Sober (alcohol) long-form descriptions via locale-specific replacements, then
writes scripts/quitzyn_locale_extras.json for generate_quitzyn_native_metadata.py.
"""
from __future__ import annotations

import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = Path(__file__).resolve().parent
SOBER_SCRIPTS = ROOT.parent / "sober" / "scripts"
OUT = SCRIPTS / "quitzyn_locale_extras.json"
EN_DESC = (ROOT / "fastlane/metadata/en-US/description.txt").read_text(encoding="utf-8").strip()
SUPPORTED = json.loads((SCRIPTS / "asc-supported-locales.json").read_text())["locales"]

RULES: dict[str, list[tuple[str, str]] | str] = {
    "en-US": [
        (
            "Count every alcohol-free day, check in once a day, and watch your garden bloom as your streak grows.",
            "Count each nicotine-free day, check in daily, and watch your garden bloom.",
        ),
        (
            "Private, simple, and free to start. No account needed.",
            "Quit Zyn, pouches, vaping or dip. Private, simple, and free to start. No account needed.",
        ),
        ("alcohol-free", "nicotine-free"),
        ("alcohol free", "nicotine-free"),
        ("alcohol", "nicotine"),
        ("drinking", "pouches"),
        ("drink ", "pouch "),
        ("sober", "nicotine-free"),
        ("sobriety", "nicotine-free"),
        ("dry day", "nicotine-free day"),
    ],
    "de-DE": [
        ("alkoholfreien", "nikotinfreien"),
        ("alkoholfreie", "nikotinfreie"),
        ("alkoholfrei", "nikotinfrei"),
        ("Alkohol", "Nikotin"),
        ("nüchtern", "nikotinfrei"),
        ("Nüchternheit", "Nikotinfreiheit"),
        ("trinken", "Beutel"),
        ("Trinken", "Beutel"),
    ],
    "fr-FR": [
        ("sans alcool", "sans nicotine"),
        ("l'alcool", "la nicotine"),
        ("alcool", "nicotine"),
        ("sobre", "sans nicotine"),
        ("sobriété", "sans nicotine"),
        ("boire", "sachets"),
    ],
    "fr-CA": "fr-FR",
    "es-ES": [
        ("sin alcohol", "sin nicotina"),
        ("alcohol", "nicotina"),
        ("sobrio", "sin nicotina"),
        ("sobriedad", "sin nicotina"),
        ("beber", "bolsitas"),
    ],
    "es-MX": "es-ES",
    "ca": [("sense alcohol", "sense nicotina"), ("alcohol", "nicotina"), ("sobri", "sense nicotina")],
    "it": [
        ("senza alcol", "senza nicotina"),
        ("alcol", "nicotina"),
        ("sobrio", "senza nicotina"),
        ("bere", "bustine"),
    ],
    "pt-BR": [
        ("sem álcool", "sem nicotina"),
        ("álcool", "nicotina"),
        ("sóbrio", "sem nicotina"),
        ("beber", "saquinhos"),
    ],
    "pt-PT": "pt-BR",
    "nl-NL": [
        ("alcoholvrije", "nikotinvrije"),
        ("alcoholvrij", "nikotinvrij"),
        ("alcohol", "nicotine"),
        ("nuchter", "nikotinvrij"),
    ],
    "pl": [
        ("bez alkoholu", "bez nikotyny"),
        ("alkoholu", "nikotyny"),
        ("alkohol", "nikotyna"),
        ("trzeźw", "bez nikotyny"),
    ],
    "sv": [("alkoholfri", "nikotinfri"), ("alkohol", "nikotin"), ("nykter", "nikotinfri")],
    "da": "sv",
    "no": "sv",
    "fi": [
        ("alkoholittomia", "nikotiinittömiä"),
        ("alkoholiton", "nikotiiniton"),
        ("alkoholia", "nikotiinia"),
        ("alkoholi", "nikotiini"),
    ],
    "cs": [("bez alkoholu", "bez nikotinu"), ("alkoholu", "nikotinu"), ("alkohol", "nikotin")],
    "sk": [("bez alkoholu", "bez nikotínu"), ("alkoholu", "nikotínu"), ("alkohol", "nikotín")],
    "hu": [("alkoholmentes", "nikotinmentes"), ("alkohol", "nikotin")],
    "ro": [("fără alcool", "fără nicotină"), ("alcool", "nicotină")],
    "hr": [("bez alkohola", "bez nikotina"), ("alkohola", "nikotina"), ("alkohol", "nikotin")],
    "sl-SI": "hr",
    "tr": [("alkolsüz", "nikotinsiz"), ("alkol", "nikotin")],
    "ru": [
        ("без алкоголя", "без никотина"),
        ("алкоголя", "никотина"),
        ("алкоголь", "никотин"),
        ("трезв", "без никотина"),
    ],
    "uk": [
        ("без алкоголю", "без нікотину"),
        ("алкоголю", "нікотину"),
        ("алкоголь", "нікотин"),
    ],
    "ar-SA": [
        ("بدون كحول", "بدون نيكوتين"),
        ("الكحول", "النيكوتين"),
        ("كحول", "نيكوتين"),
    ],
    "he": [
        ("נטול אלכוהול", "ללא ניקוטין"),
        ("אלכוהול", "ניקוטין"),
        ("פיכחון", "ללא ניקוטין"),
    ],
    "hi": [("मदमुक्त", "निकोटीन मुक्त"), ("शराब", "निकोटीन"), ("शराब मुक्त", "निकोटीन मुक्त")],
    "bn-BD": [("মদমুক্ত", "নিকোটিন মুক্ত"), ("মদ", "নিকোটিন")],
    "gu-IN": [("દારૂ મુક્ત", "નિકોટિન મુક્ત"), ("દારૂ", "નિકોટિન")],
    "kn-IN": [("ಮದ್ಯಮುಕ್ತ", "ನಿಕೋಟಿನ್ ಮುಕ್ತ"), ("ಮದ್ಯ", "ನಿಕೋಟಿನ್")],
    "ml-IN": [("മദ്യമുക്ത", "നിക്കോട്ടിൻ ഫ്രീ"), ("മദ്യം", "നിക്കോട്ടിൻ")],
    "mr-IN": [("दारूमुक्त", "निकोटीन मुक्त"), ("दारू", "निकोटीन")],
    "or-IN": [("ମଦ୍ୟମୁକ୍ତ", "ନିକୋଟିନ ମୁକ୍ତ"), ("ମଦ୍ୟ", "ନିକୋଟିନ")],
    "pa-IN": [("ਸ਼ਰਾਬ ਮੁਕਤ", "ਨਿਕੋਟੀਨ ਮੁਕਤ"), ("ਸ਼ਰਾਬ", "ਨਿਕੋਟੀਨ")],
    "ta-IN": [("மதுவிலா", "நிக்கோட்டின் இல்லா"), ("மது", "நிக்கோட்டின்")],
    "te-IN": [("మద్యముక్త", "నికోటిన్ ఫ్రీ"), ("మద్యం", "నికోటిన్")],
    "ur-PK": [("شراب سے پاک", "نکوٹین سے پاک"), ("شراب", "نکوٹین")],
    "ja": [
        ("アルコールフリー", "ニコチンフリー"),
        ("アルコール", "ニコチン"),
        ("禁酒", "禁煙"),
        ("お酒", "ニコチン"),
        ("飲酒", "ポーチ"),
    ],
    "ko": [
        ("무알코올", "니코틴 프리"),
        ("알코올", "니코틴"),
        ("금주", "금연"),
        ("음주", "니코틴"),
    ],
    "zh-Hans": [
        ("无酒精", "无烟碱"),
        ("酒精", "烟碱"),
        ("戒酒", "戒烟"),
        ("清醒", "无烟碱"),
    ],
    "zh-Hant": [
        ("無酒精", "無菸鹼"),
        ("酒精", "菸鹼"),
        ("戒酒", "戒菸"),
        ("清醒", "無菸鹼"),
    ],
    "th": [
        ("ไร้แอลกอฮอล์", "ปลอดนิโคติน"),
        ("แอลกอฮอล์", "นิโคติน"),
        ("เลิกเหล้า", "เลิกบุหรี่"),
    ],
    "vi": [("không cồn", "không nicotin"), ("cồn", "nicotin"), ("rượu", "nicotin")],
    "id": [("bebas alkohol", "bebas nikotin"), ("alkohol", "nikotin")],
    "ms": "id",
    "el": [
        ("χωρίς αλκοόλ", "χωρίς νικοτίνη"),
        ("αλκοόλ", "νικοτίνη"),
        ("νίκη", "νικοτίνη"),
    ],
}

EXTRA_DESC = [
    ("Sober Tracker", "Quit Zyn"),
    ("sober tracker", "Quit Zyn"),
    ("jackwallner.github.io/sober", "jackwallner.github.io/quitzyn"),
    ("NIAAA, CDC, and AHA", "ACS, NCI, and Truth Initiative"),
    ("blood sugar stabilize", "nicotine clears"),
    ("liver health", "lung recovery"),
    ("dry day", "nicotine-free day"),
    ("Dry day", "Nicotine-free day"),
    ("dry days", "nicotine-free days"),
]

RELEASE_NOTES: dict[str, str] = {
    "en-US": "First release. Track your nicotine-free days, grow your garden, and watch your health recover one milestone at a time. Thank you for being here.",
    "en-GB": "First release. Track your nicotine-free days, grow your garden, and watch your health recover one milestone at a time. Thank you for being here.",
    "en-AU": "First release. Track your nicotine-free days, grow your garden, and watch your health recover one milestone at a time. Thank you for being here.",
    "en-CA": "First release. Track your nicotine-free days, grow your garden, and watch your health recover one milestone at a time. Thank you for being here.",
    "de-DE": "Erstveröffentlichung. Zähle nikotinfreie Tage, lass deinen Garten wachsen und sieh deine Gesundheit Schritt für Schritt zurückkehren. Danke, dass du dabei bist.",
    "fr-FR": "Première version. Comptez vos jours sans nicotine, faites grandir votre jardin et regardez votre santé revenir, étape par étape. Merci d'être là.",
    "fr-CA": "Première version. Comptez vos jours sans nicotine, faites grandir votre jardin et regardez votre santé revenir. Merci d'être là.",
    "es-ES": "Primer lanzamiento. Cuenta tus días sin nicotina, haz crecer tu jardín y mira recuperarse tu salud, hito a hito. Gracias por estar aquí.",
    "es-MX": "Primer lanzamiento. Cuenta tus días sin nicotina, haz crecer tu jardín y mira recuperarse tu salud. Gracias por estar aquí.",
    "ca": "Primera versió. Compta els dies sense nicotina, fes créixer el jardí i mira com torna la salut, pas a pas. Gràcies per ser-hi.",
    "it": "Primo rilascio. Conta i giorni senza nicotina, fai crescere il giardino e guarda tornare la salute, passo dopo passo. Grazie per essere qui.",
    "pt-BR": "Primeiro lançamento. Conte seus dias sem nicotina, cultive seu jardim e veja sua saúde voltar, marco a marco. Obrigado por estar aqui.",
    "pt-PT": "Primeiro lançamento. Conte os seus dias sem nicotina, cultive o jardim e veja a sua saúde voltar. Obrigado por estar aqui.",
    "nl-NL": "Eerste release. Tel je nicotinevrije dagen, laat je tuin groeien en zie je gezondheid stap voor stap terugkomen. Bedankt dat je er bent.",
    "pl": "Pierwsze wydanie. Licz dni bez nikotyny, rozwijaj ogród i obserwuj powrót zdrowia krok po kroku. Dziękujemy, że jesteś z nami.",
    "sv": "Första versionen. Räkna nikotinfria dagar, låt trädgården växa och se hälsan återvända steg för steg. Tack för att du är här.",
    "da": "Første udgivelse. Tæl nikotinfrie dage, lad haven vokse og se sundheden vende tilbage trin for trin. Tak fordi du er med.",
    "no": "Første utgivelse. Tell nikotinfrie dager, la hagen vokse og se helsen komme tilbake steg for steg. Takk for at du er her.",
    "fi": "Ensimmäinen julkaisu. Laske nikotiinittömiä päiviä, kasvata puutarhaa ja seuraa terveytesi palautumista askel askeleelta. Kiitos, että olet mukana.",
    "cs": "První vydání. Počítejte dny bez nikotinu, nechte zahradu růst a sledujte návrat zdraví krok za krokem. Děkujeme, že jste s námi.",
    "sk": "Prvé vydanie. Počítajte dni bez nikotínu, nechajte záhradu rásť a sledujte návrat zdravia krok za krokom. Ďakujeme, že ste s nami.",
    "hu": "Első kiadás. Számolja a nikotinmentes napokat, növelje a kertet, és figyelje egészsége visszatérését lépésről lépésre. Köszönjük, hogy itt van.",
    "ro": "Prima lansare. Numără zilele fără nicotină, cultivă grădina și urmărește cum sănătatea revine pas cu pas. Mulțumim că ești aici.",
    "hr": "Prvo izdanje. Brojite dane bez nikotina, uzgajajte vrt i pratite povratak zdravlja korak po korak. Hvala što ste s nama.",
    "sl-SI": "Prva izdaja. Štejte dneve brez nikotina, gojite vrt in opazujte vračanje zdravja korak za korakom. Hvala, da ste z nami.",
    "el": "Πρώτη έκδοση. Μετρήστε τις ημέρες χωρίς νικοτίνη, αναπτύξτε τον κήπο και δείτε την υγεία να επιστρέφει βήμα βήμα. Ευχαριστούμε που είστε εδώ.",
    "tr": "İlk sürüm. Nikotinsiz günlerinizi sayın, bahçenizi büyütün ve sağlığınızın adım adım geri geldiğini izleyin. Burada olduğunuz için teşekkürler.",
    "ru": "Первый релиз. Считайте дни без никотина, выращивайте сад и наблюдайте, как здоровье возвращается шаг за шагом. Спасибо, что вы с нами.",
    "uk": "Перший реліз. Рахуйте дні без нікотину, вирощуйте сад і спостерігайте, як здоров'я повертається крок за кроком. Дякуємо, що ви з нами.",
    "ar-SA": "الإصدار الأول. تتبع أيامك الخالية من النيكوتين، أنمِ حديقتك وشاهد صحتك تعود خطوة بخطوة. شكرًا لوجودك معنا.",
    "he": "גרסה ראשונה. ספרו ימים ללא ניקוטין, גדלו את הגינה וצפו בבריאות חוזרת צעד אחר צעד. תודה שאתם כאן.",
    "hi": "पहला संस्करण। अपने निकोटीन-मुक्त दिन गिनें, अपना बगीचा बढ़ाएं और अपने स्वास्थ्य को धीरे-धीरे लौटते देखें। यहाँ होने के लिए धन्यवाद।",
    "bn-BD": "প্রথম রিলিজ। নিকোটিন-মুক্ত দিন গণনা করুন, বাগান বাড়ান এবং স্বাস্থ্য ধীরে ধীরে ফিরে আসতে দেখুন। এখানে থাকার জন্য ধন্যবাদ।",
    "gu-IN": "પ્રથમ રિલીઝ. નિકોટિન-મુક્ત દિવસો ગણો, બગીચો વધારો અને સ્વાસ્થ્ય ધીમે ધીમે પાછું આવતું જુઓ. અહીં હોવા બદલ આભાર.",
    "kn-IN": "ಮೊದಲ ಬಿಡುಗಡೆ. ನಿಕೋಟಿನ್-ಮುಕ್ತ ದಿನಗಳನ್ನು ಎಣಿಸಿ, ತೋಟವನ್ನು ಬೆಳೆಸಿ ಮತ್ತು ಆರೋಗ್ಯ ನಿಧಾನವಾಗಿ ಹಿಂತಿರುಗುವುದನ್ನು ನೋಡಿ. ಇಲ್ಲಿ ಇರುವುದಕ್ಕೆ ಧನ್ಯವಾದಗಳು.",
    "ml-IN": "ആദ്യ റിലീസ്. നിക്കോട്ടിൻ ഫ്രീ ദിവസങ്ങൾ എണ്ണുക, ഗാർഡൻ വളർത്തുക, ആരോഗ്യം ക്രമേണ തിരിച്ചുവരുന്നത് കാണുക. ഇവിടെയുണ്ടായതിന് നന്ദി.",
    "mr-IN": "पहिली आवृत्ती. निकोटीन-मुक्त दिवस मोजा, बाग वाढवा आणि आरोग्य हळूहळू परत येताना पहा. येथे असल्याबद्दल धन्यवाद.",
    "or-IN": "ପ୍ରଥମ ରିଲିଜ୍। ନିକୋଟିନ-ମୁକ୍ତ ଦିନ ଗଣନା କରନ୍ତୁ, ବଗିଚା ବଢ଼ାନ୍ତୁ ଏବଂ ସ୍ୱାସ୍ଥ୍ୟ ଧୀରେ ଧୀରେ ଫେରିବା ଦେଖନ୍ତୁ। ଏଠାରେ ଥିବା ପାଇଁ ଧନ୍ୟବାଦ।",
    "pa-IN": "ਪਹਿਲੀ ਰਿਲੀਜ਼। ਨਿਕੋਟੀਨ-ਮੁਕਤ ਦਿਨ ਗਿਣੋ, ਬਾਗ ਵਧਾਓ ਅਤੇ ਸਿਹਤ ਧੀਰੇ-ਧੀਰੇ ਵਾਪਸ ਆਉਂਦੀ ਦੇਖੋ। ਇੱਥੇ ਹੋਣ ਲਈ ਧੰਨਵਾਦ।",
    "ta-IN": "முதல் வெளியீடு. நிக்கோட்டின் இல்லா நாட்களை எண்ணுங்கள், தோட்டத்தை வளர்த்து, ஆரோக்கியம் படிப்படியாக திரும்புவதைப் பாருங்கள். இங்கே இருப்பதற்கு நன்றி.",
    "te-IN": "మొదటి రిలీజ్. నికోటిన్ ఫ్రీ రోజులను లెక్కించండి, తోటను పెంచండి మరియు ఆరోగ్యం క్రమంగా తిరిగి రావడం చూడండి. ఇక్కడ ఉన్నందుకు ధన్యవాదాలు.",
    "ur-PK": "پہلی ریلیز۔ نکوٹین سے پاک دن گنیں، باغ بڑھائیں اور صحت آہستہ آہستہ واپس آتے دیکھیں۔ یہاں ہونے کا شکریہ۔",
    "ja": "初回リリース。ニコチンフリーの日数を記録し、ガーデンを育て、健康の回復を一つひとつの節目で確認できます。ご利用ありがとうございます。",
    "ko": "첫 출시. 니코틴 프리 일수를 기록하고, 정원을 키우며, 건강이 돌아오는 과정을 함께 확인하세요. 함께해 주셔서 감사합니다.",
    "zh-Hans": "首次发布。记录无烟碱天数，培育你的花园，一步步见证健康恢复。感谢你的使用。",
    "zh-Hant": "首次發布。記錄無菸鹼天數，培育你的花園，一步步見證健康恢復。感謝你的使用。",
    "th": "เปิดตัวครั้งแรก นับวันปลอดนิโคติน ปลูกสวนให้เติบโต และดูสุขภาพค่อย ๆ กลับมาทีละขั้น ขอบคุณที่อยู่กับเรา",
    "vi": "Phát hành đầu tiên. Đếm ngày không nicotin, nuôi khu vườn và xem sức khỏe dần hồi phục từng bước. Cảm ơn bạn đã ở đây.",
    "id": "Rilis perdana. Hitung hari bebas nikotin, kembangkan taman Anda, dan lihat kesehatan pulih selangkah demi selangkah. Terima kasih sudah di sini.",
    "ms": "Keluaran pertama. Kira hari bebas nikotin, kembangkan taman anda, dan lihat kesihatan kembali selangkah demi selangkah. Terima kasih kerana bersama kami.",
}

PROMO_OVERRIDES: dict[str, str] = {
    "en-US": "Count each nicotine-free day, check in daily, and watch your garden bloom. Quit Zyn, pouches, vaping or dip. Private, simple, and free to start.",
    "en-GB": "Count each nicotine-free day, check in daily, and watch your garden bloom. Quit Zyn, pouches, vaping or dip. Private, simple, and free to start.",
    "en-AU": "Count each nicotine-free day, check in daily, and watch your garden bloom. Quit Zyn, pouches, vaping or dip. Private, simple, and free to start.",
    "en-CA": "Count each nicotine-free day, check in daily, and watch your garden bloom. Quit Zyn, pouches, vaping or dip. Private, simple, and free to start.",
    "ja": "ニコチンフリーの日を数え、毎日チェックインして、連続記録とともにガーデンを育てましょう。Zyn、スヌース、ポーチ、ベイプ。プライベートでシンプル、無料。",
}


def resolve_rules(loc: str) -> list[tuple[str, str]]:
    r = RULES.get(loc, [])
    if isinstance(r, str):
        return resolve_rules(r)
    base = list(RULES.get("en-US", [])) if loc.startswith("en-") else []
    return base + list(r)


def adapt_text(text: str, loc: str) -> str:
    text = text.replace("Sober Tracker", "Quit Zyn").replace("sober tracker", "Quit Zyn")
    text = text.replace("jackwallner.github.io/sober", "jackwallner.github.io/quitzyn")
    for a, b in resolve_rules(loc):
        text = text.replace(a, b)
    for a, b in EXTRA_DESC:
        text = text.replace(a, b)
    return text


def strip_dashes(text: str) -> str:
    text = text.replace("—", ", ").replace(" – ", ", ").replace("–", ", ")
    text = re.sub(r",\s*,", ",", text)
    return text.strip()


def load_sober_meta():
    spec = importlib.util.spec_from_file_location("sober_meta", SOBER_SCRIPTS / "aso_native_metadata.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def build_promotional(sober_locales: dict) -> dict[str, str]:
    promos: dict[str, str] = {}
    for loc in SUPPORTED:
        if loc in PROMO_OVERRIDES:
            promos[loc] = strip_dashes(PROMO_OVERRIDES[loc])
            continue
        path = ROOT.parent / "sober" / "fastlane" / "metadata" / loc / "promotional_text.txt"
        if path.exists():
            text = adapt_text(path.read_text(encoding="utf-8").strip(), loc)
        elif loc in sober_locales:
            text = adapt_text(sober_locales[loc].get("description", "").split("\n")[0], loc)
        else:
            text = RELEASE_NOTES.get(loc, RELEASE_NOTES["en-US"])
        text = strip_dashes(text)
        if len(text) > 170:
            text = text[:167].rstrip(" ,.;") + "..."
        promos[loc] = text
    return promos


def build_descriptions(sober_locales: dict) -> dict[str, str]:
    descriptions: dict[str, str] = {}
    for loc in SUPPORTED:
        if loc.startswith("en-"):
            desc = EN_DESC if loc != "en-GB" else EN_DESC.replace("cutting back", "cutting down")
        elif loc in sober_locales:
            desc = adapt_text(sober_locales[loc]["description"], loc)
        else:
            desc = EN_DESC
        descriptions[loc] = strip_dashes(desc)
    return descriptions


def main() -> int:
    sober = load_sober_meta()
    payload = {
        "promotional": build_promotional(sober.LOCALES),
        "release_notes": {loc: strip_dashes(RELEASE_NOTES.get(loc, RELEASE_NOTES["en-US"])) for loc in SUPPORTED},
        "descriptions": build_descriptions(sober.LOCALES),
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} ({len(SUPPORTED)} locales)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
