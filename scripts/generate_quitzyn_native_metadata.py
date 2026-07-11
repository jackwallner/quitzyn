#!/usr/bin/env python3
"""Generate scripts/aso_native_metadata.py for Quit Zyn (all 50 ASC locales).

Native name, subtitle, keywords, and description per locale. No English fallbacks
in foreign storefronts.
"""
from __future__ import annotations

import json
import re
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = Path(__file__).resolve().parent
OUT = SCRIPTS / "aso_native_metadata.py"
EXTRAS_PATH = SCRIPTS / "quitzyn_locale_extras.json"
EN_DESC = (ROOT / "fastlane/metadata/en-US/description.txt").read_text(encoding="utf-8").strip()

# (name ≤30, subtitle ≤30, keywords ≤100) — validated before write
CORE: dict[str, tuple[str, str, str]] = {
    "ar-SA": (
        "إقلاع السنوس: أكياس ونيكوتين",
        "عداد أيام خالية من النيكوتين",
        "فيب,إدمان,امتناع,عادة,يوميات,سلسلة,تبغ,تقويم,صحة,خاص,انتكاسة,velo,snus,zyn,nicotine,pouch,puff,stop",
    ),
    "bn-BD": (
        "স্নাস ছাড়ুন – পাউচ ট্র্যাকার",
        "নিকোটিন মুক্ত দিন গণনা ও বাগান",
        "ভেপ,ছাড়া,আসক্তি,সংযম,অভ্যাস,ডায়েরি,ধারা,তামাক,ক্যালেন্ডার,স্বাস্থ্য,ব্যক্তিগত,snus,velo,zyn,puff",
    ),
    "ca": (
        "Deixa el snus: Bosses & velo",
        "Comptador dies sense nicotina",
        "tabac,vape,addicció,abstinència,recuperació,hàbit,diari,sèrie,calendari,salut,privat,gana,zyn,puff",
    ),
    "cs": (
        "Přestaň snus: Sáčky & velo",
        "Počítadlo dnů bez nikotinu",
        "tabák,vape,přestat,závislost,abstinence,zvyk,deník,série,kalendář,zdraví,soukromí,chuť,žvýkat,zyn",
    ),
    "da": (
        "Stop snus: Poser & prillor",
        "Nikotinfri dagtæller & have",
        "velo,tobak,vape,afhængighed,abstinens,vane,dagbog,serie,kalender,sundhed,privat,trang,tygge,zyn,puff",
    ),
    "de-DE": (
        "Snus aufhören: Beutel & Zyn",
        "Nikotinfreie Tage & Garten",
        "velo,tabak,kauen,entzug,gewohnheit,serie,verlangen,kalender,gesundheit,privat,rückfall,dampfen,puff",
    ),
    "el": (
        "Σταμάτα snus: Φακελάκια & velo",
        "Μετρητής ημερών χωρίς νικοτίνη",
        "καπνός,διακοπή,εξάρτηση,αποχή,συνήθεια,ημερολόγιο,σειρά,υγεία,ιδιωτικό,λαχτάρα,μάσηση,zyn,nicotine",
    ),
    "en-AU": (
        "Quit Zyn: Pouch & Snus Tracker",
        "Nicotine Free Days & Garden",
        "velo,buzz,zone,tobacco,dip,chew,oral,rogue,cope,stop,streak,recovery,craving,puff,withdrawal,vape",
    ),
    "en-CA": (
        "Quit Zyn: Pouch & Snus Tracker",
        "Nicotine Free Days & Garden",
        "velo,buzz,zone,tobacco,dip,chew,oral,rogue,cope,stop,streak,recovery,craving,puff,withdrawal,vape",
    ),
    "en-GB": (
        "Quit Zyn: Pouch & Snus Tracker",
        "Nicotine Free Days & Garden",
        "velo,buzz,zone,tobacco,dip,chew,oral,rogue,cope,stop,streak,recovery,craving,puff,withdrawal,vape",
    ),
    "en-US": (
        "Quit Zyn: Pouch & Snus Tracker",
        "Nicotine Free Days & Garden",
        "velo,buzz,zone,tobacco,dip,chew,oral,rogue,cope,stop,streak,recovery,craving,puff,withdrawal,vape",
    ),
    "es-ES": (
        "Dejar el snus: Bolsas & velo",
        "Contador de días sin nicotina",
        "tabaco,vapeo,adicción,antojo,abstinencia,recuperación,habito,diario,serie,salud,masticar,privado,zyn",
    ),
    "es-MX": (
        "Dejar el snus: Bolsas & velo",
        "Contador de días sin nicotina",
        "tabaco,adicción,antojo,abstinencia,habito,diario,serie,vape,pouch,nicotine,stop,puff,tobacco,salud",
    ),
    "fi": (
        "Lopeta nuuska: Pussit & snus",
        "Nikotiiniton päivälaskuri",
        "velo,tupakka,vape,lopettaa,riippuvuus,tottumus,päiväkirja,sarja,kalenteri,terveys,yksityinen,himo",
    ),
    "fr-CA": (
        "Arrêter snus: Sachets & velo",
        "Compteur jours sans nicotine",
        "tabac,vapotage,sevrage,envie,habitude,journal,série,dépendance,abstinence,récupération,chiquer,privé",
    ),
    "fr-FR": (
        "Arrêter snus: Sachets & velo",
        "Compteur jours sans nicotine",
        "tabac,vapotage,sevrage,envie,habitude,journal,série,dépendance,abstinence,récupération,chiquer,privé",
    ),
    "gu-IN": (
        "સ્નસ છોડો – પાઉચ ટ્રેકર એપ",
        "નિકોટિન મુક્ત દિવસ ગણતરી બગીચો",
        "વેપ,છોડવું,વ્યસન,સંયમ,આદત,ડાયરી,શ્રેણી,તમાકુ,કેલેન્ડર,આરોગ્ય,snus,velo,zyn,nicotine,puff,stop,streak",
    ),
    "he": (
        "הפסקת snus: שקיות וסנוס velo",
        "מונה ימים נקיים מניקוטין וגן",
        "וייפ,הפסקה,התמכרות,התנזרות,הרגל,יומן,רצף,טבק,לוחשנה,בריאות,zyn,nicotine,pouch,פרטי,puff,stop,streak",
    ),
    "hi": (
        "स्नूस छोड़ें – पाउच ट्रैकर",
        "निकोटीन मुक्त दिन गिनती बगीचा",
        "वेप,छोड़ना,लत,संयम,आदत,डायरी,स्ट्रीक,तंबाकू,कैलेंडर,स्वास्थ्य,निजी,पुनरावृत्ति,snus,velo,zyn,puff",
    ),
    "hr": (
        "Prestani snus: Vrećice & velo",
        "Brojač dana bez nikotina & vrt",
        "duhan,vape,prestati,ovisnost,apstinencija,navika,dnevnik,niz,kalendar,zdravlje,privatno,želja,zyn",
    ),
    "hu": (
        "Snus abbahagy: Tasakok & velo",
        "Nikotinfüggetlen napok & kert",
        "dohány,vape,függőség,elvonás,szokás,napló,sorozat,naptár,egészség,vágy,rágás,zyn,nicotine,puff,stop",
    ),
    "id": (
        "Berhenti snus: Kantong & velo",
        "Hitung hari bebas nikotin",
        "vape,kecanduan,pantang,kebiasaan,diari,rangkai,tembakau,kalender,kesehatan,pribadi,kambuh,zyn,puff",
    ),
    "it": (
        "Smetti snus: Bustine & velo",
        "Contatore giorni no nicotina",
        "tabacco,svapo,smettere,dipendenza,astinenza,diario,serie,calendario,salute,privato,voglia,masticare",
    ),
    "ja": (
        "ニコチン袋・スヌース・ポーチ禁煙追跡ZYNアプリ版",
        "無ニコチン日数カウンター・バーチャル庭園ZYNアプリ",
        "ポーチ,ベイプ,禁煙,依存,離脱,渇望,習慣,日記,連続,記録,カレンダー,ウィジェット,健康,非公開,再発,velo,snus,zyn,puff,stop,streak,tobacco,vape",
    ),
    "kn-IN": (
        "ಸ್ನೂಸ್ ಬಿಡಿ – ಪಾಉಚ್ ಟ್ರ್ಯಾಕರ್",
        "ನಿಕೋಟಿನ್ ಮುಕ್ತ ದಿನಗಳ ಎಣಿಕೆ ತೋಟ",
        "ವೇಪ್,ಬಿಡುವುದು,ಚಟ,ಸಂಯಮ,ಅಭ್ಯಾಸ,ಡೈರಿ,ಸರಣಿ,ಹೊಗೆತಂಬಾಕು,ಕ್ಯಾಲೆಂಡರ್,ಆರೋಗ್ಯ,snus,velo,zyn,nicotine,puff,stop",
    ),
    "ko": (
        "스누스 끊기 니코틴 파우치 ZYN 추적 앱 프로그램",
        "무니코틴 프리 일수 카운터 & 가상 정원 성장",
        "베이프,금연,중독,절제,갈망,습관,일기,연속,기록,캘린더,위젯,건강,비공개,재발,velo,snus,puff,stop,streak,tobacco,withdrawal,vape",
    ),
    "ml-IN": (
        "സ്നൂസ് നിർത്തുക – പൗച്ച് ആപ്പ്",
        "നികോട്ടിൻ ഫ്രീ ദിവസങ്ങൾ തോട്ടം",
        "വേപ്പ്,നിർത്തൽ,ആസക്തി,വർജനം,ശീലം,ഡയറി,സീരീസ്,പുകയില,കലണ്ടർ,ആരോഗ്യം,snus,velo,zyn,nicotine,puff,stop",
    ),
    "mr-IN": (
        "स्नूस सोडा – पाउच ट्रॅकर ऍप",
        "निकोटीन मुक्त दिवस मोजणी बाग",
        "वेप,सोडणे,व्यसन,संयम,सवय,डायरी,मालिका,तंबाखू,दिनदर्शिका,आरोग्य,snus,velo,zyn,nicotine,puff,stop,vape",
    ),
    "ms": (
        "Berhenti snus: Kantung & velo",
        "Hitung hari tanpa nikotin",
        "vape,ketagihan,pantang,tabiat,diari,rangkai,tembakau,kalendar,kesihatan,kambuh,peribadi,nicotine,zyn",
    ),
    "nl-NL": (
        "Stop met snus: Zakjes & velo",
        "Nikotinvrije dagen & tuin",
        "tabak,dampen,verslaving,ontwenning,gewoonte,dagboek,serie,kalender,gezondheid,privé,verlangen,kauwen",
    ),
    "no": (
        "Slutt med snus: Poser & velo",
        "Nikotinfri dagteller & hage",
        "tobakk,vape,avhengighet,avholdenhet,vanedagbok,serie,kalender,helse,privat,sug,tygge,tilbakefall,zyn",
    ),
    "or-IN": (
        "ସ୍ନସ ଛାଡ଼ – ପାଉଚ ଟ୍ରାକର ଆପ୍",
        "ନିକୋଟିନ ମୁକ୍ତ ଦିନ ଗଣନା ବଗିଚା",
        "ଭେପ,ଛାଡିବା,ଆସକ୍ତି,ବିରତି,ଅଭ୍ୟାସ,ଡାଇରୀ,ଧାରା,ତମାଖୁ,କ୍ୟାଲେଣ୍ଡର,ସ୍ୱାସ୍ଥ୍ୟ,snus,velo,zyn,nicotine,puff",
    ),
    "pa-IN": (
        "ਸਨੂਸ ਛੱਡੋ – ਪਾਊਚ ਟ੍ਰੈਕਰ ਐਪ",
        "ਨਿਕੋਟੀਨ ਮੁਕਤ ਦਿਨ ਗਿਣਤੀ ਬਾਗ",
        "ਵੇਪ,ਛੱਡਣਾ,ਆਦੀ,ਸੰਜਮ,ਆਦਤ,ਡਾਇਰੀ,ਲੜੀ,ਤਮਾਕੂ,ਕੈਲੰਡਰ,ਸਿਹਤ,snus,velo,zyn,nicotine,puff,stop,streak,tobacco",
    ),
    "pl": (
        "Rzuć snusa: Saszetki & velo",
        "Dni bez nikotyny & licznik",
        "tytoń,vape,przestać,uzależnienie,odwyk,nawyk,dziennik,seria,kalendarz,zdrowie,prywatny,głód,żuć,zyn",
    ),
    "pt-BR": (
        "Parar o snus: Saquinhos & velo",
        "Contador de dias sem nicotina",
        "tabaco,vape,abstinência,recuperação,diário,serie,calendário,privado,recaída,zyn,nicotine,puff,stop",
    ),
    "pt-PT": (
        "Parar o snus: Saquinhos & velo",
        "Contador de dias sem nicotina",
        "tabaco,vape,abstinência,recuperação,diário,serie,calendário,privado,recaída,zyn,nicotine,puff,stop",
    ),
    "ro": (
        "Oprește snus: Plicuri & velo",
        "Contor zile fără nicotină",
        "tutun,vape,opri,dependență,abstinență,obicei,jurnal,serie,calendar,sănătate,privat,poftă,recădere",
    ),
    "ru": (
        "Брось snus: Пакетики & velo",
        "Счётчик дней без никотина",
        "табак,вейп,бросить,зависимость,воздержание,привычка,дневник,серия,календарь,здоровье,тяга,жевать,zyn",
    ),
    "sk": (
        "Prestaň snus: Vrecká & velo",
        "Počítadlo dní bez nikotínu",
        "tabak,vape,prestať,závislosť,abstinencia,zvyk,denník,séria,kalendár,zdravie,súkromie,chuť,žuť,zyn",
    ),
    "sl-SI": (
        "Nehaj snus: Vrečke & velo",
        "Števec brez nikotina & vrt",
        "tobak,vape,nehati,odvisnost,abstinenca,navada,dnevnik,niz,koledar,zdravje,zasebno,želja,žvečiti,zyn",
    ),
    "sv": (
        "Sluta snusa: Prillor & snus",
        "Fri från nikotin dagräknare",
        "velo,tobak,vape,beroende,abstinens,vana,dagbok,serie,kalender,hälsa,privat,sug,tugga,återfall,zyn",
    ),
    "ta-IN": (
        "ஸ்னூஸ் விடு – பவுச் டிராக்கர்",
        "நாட்கள் எண்ணிக்கை & தோட்டம்",
        "வேப்,அடிமை,தவிர்ப்பு,பழக்கம்,டைரி,தொடர்,புகையிலை,நாட்காட்டி,ஆரோக்கியம்,snus,velo,zyn,nicotine,puff",
    ),
    "te-IN": (
        "స్నూస్ వదులు – పౌచ్ ట్రాకర్",
        "నికోటిన్ లేని రోజుల లెక్క తోట",
        "వేప్,వదలడం,వ్యసనం,సంయమం,అలవాటు,డైరీ,సిరీస్,పొగాకు,క్యాలెండర్,ఆరోగ్యం,snus,velo,zyn,nicotine,puff",
    ),
    "th": (
        "เลิก snus: ถุงนิโคติน & velo",
        "นับวันไม่นิโคติน & สวนเสมือน",
        "ซอง,วีป,ติด,งด,นิสัย,ไดอารี่,สตรีค,ยาสูบ,ปฏิทิน,สุขภาพ,ส่วนตัว,กลับมา,nicotine,pouch,zyn,puff,stop",
    ),
    "tr": (
        "Bırak snusu: Poşet & velo",
        "Nikotinsiz gün sayacı & bahçe",
        "tütün,vape,bağımlılık,ayıklık,alışkanlık,dizi,takvim,sağlık,istek,çiğneme,özel,nüks,zyn,nicotine",
    ),
    "uk": (
        "Кинь snus: Пакетики & velo",
        "Лічильник днів без нікотину",
        "тютюн,вейп,кинути,залежність,утримання,звичка,щоденник,серія,календар,здоров'я,тяга,жувати,zyn,puff",
    ),
    "ur-PK": (
        "سنوس چھوڑیں – پاؤچ ٹریکر ایپ",
        "نیکوٹین فری دن گنتی اور باغ",
        "ویپ,چھوڑنا,نشہ,پرہیز,عادت,ڈائری,سلسلہ,تمباکو,کیلنڈر,صحت,snus,velo,zyn,nicotine,puff,stop,streak,vape",
    ),
    "vi": (
        "Bỏ thuốc snus: Túi & velo",
        "Đếm ngày không nicotine & vườn",
        "vape,cai,nghiện,kiêng,thóiquen,nhậtký,chuỗi,lich,suckhoe,riengtu,talai,pouch,zyn,puff,stop,streak",
    ),
    "zh-Hans": (
        "戒瘾助手｜尼古丁袋ZYN无烟碱戒断追踪应用助手APP",
        "无烟碱日计数器・虚拟花园成长应用助手VELOZYN",
        "唇烟,电子烟,戒烟,戒断,渴望,习惯,日记,连续,记录,计数器,日历,小组件,健康,私密,复吸,咀嚼,snus,zyn,puff,stop,streak,vape,nicotine,tobacco",
    ),
    "zh-Hant": (
        "戒癮助手｜尼古丁袋ZYN無菸鹼戒斷追蹤應用助手APP",
        "無菸鹼日計數器・虛擬花園成長應用助手VELOZYN",
        "唇煙,電子煙,戒菸,戒斷,渴望,習慣,日記,連續,記錄,計數器,日曆,小工具,健康,私密,復吸,咀嚼,snus,zyn,puff,stop,streak,vape,nicotine,tobacco",
    ),
}

DESCRIPTIONS: dict[str, str] = {
    "en-US": EN_DESC,
    "en-GB": EN_DESC.replace("cutting back", "cutting down"),
    "en-AU": EN_DESC,
    "en-CA": EN_DESC,
    "de-DE": """Quit Zyn macht es einfach, nikotinfrei zu bleiben. Zähle jeden Tag ohne Beutel, checke einmal täglich ein und sieh zu, wie dein virtueller Garten mit deiner Serie wächst. Ob du Zyn, Snus, Nikotinbeutel, Kautabak oder Dampfen aufgibst: alles bleibt privat auf deinem Gerät. Kein Konto nötig.

DEIN FORTSCHRITT AUF EINEN BLICK (KOSTENLOS)
• Tagezähler mit Tagen, Stunden und längster Serie
• Täglicher Check-in mit einem Tipp
• Kalender mit allen nikotinfreien Tagen
• Meilensteine, wenn die Tage wachsen

GARTEN, DER MIT DIR WÄCHST (KOSTENLOS)
• Virtueller Garten, der mit jedem nikotinfreien Tag blüht
• Neues Wachstum, wenn deine Serie steigt

WIDGETS & APPLE WATCH (KOSTENLOS)
• Home- und Sperrbildschirm-Widgets mit Tageszahl
• Apple-Watch-Begleiter für Check-in und Serie

PRIVAT
• Alle Daten bleiben auf deinem Gerät. Kein Konto, keine Werbung, kein Tracking.

BLOOM+ (OPTIONAL)
Vollständige Nikotin-Erholungs-Timeline, Tagebuch, Erfolge, Ersparnisse, mehr Baumarten. Kostenlose Testphase für neue Abonnenten.

Kostenlos laden. Bloom+ jederzeit upgraden.

Abonnement: Bloom+ als Auto-Abo (Monat 4,99 $ / Jahr 29,99 $ mit 7 Tagen Test) oder einmalig 59,99 $. Verwaltung unter Einstellungen > Apple-ID > Abonnements.
Datenschutz: https://jackwallner.github.io/quitzyn/privacy-policy.html
Nutzungsbedingungen: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/""",
    "fr-FR": """Quit Zyn rend la vie sans nicotine simple et motivante. Comptez chaque jour sans sachets, faites un check-in quotidien et regardez un jardin virtuel grandir avec votre série. Que vous arrêtiez Zyn, snus, sachets, tabac à chiquer ou vape, tout reste privé sur votre appareil. Aucun compte requis.

VOTRE PROGRÈS (GRATUIT)
• Compteur de jours, heures et plus longue série
• Check-in quotidien en un geste
• Calendrier de tous vos jours sans nicotine
• Jalons au fil des jours

JARDIN QUI GRANDIT (GRATUIT)
• Jardin virtuel qui fleurit à chaque jour sans nicotine

WIDGETS & APPLE WATCH (GRATUIT)
• Widgets écran d'accueil et verrouillage
• Compagnon Apple Watch

PRIVÉ
• Données sur l'appareil uniquement. Pas de compte, pas de pub, pas de suivi.

BLOOM+ (OPTIONNEL)
Timeline complète de récupération, journal, succès, économies, plus d'espèces. Essai gratuit pour les nouveaux abonnés.

Téléchargement gratuit. Passez à Bloom+ quand vous voulez.

Abonnement : Bloom+ en renouvellement auto (mensuel 4,99 $ / annuel 29,99 $ avec 7 jours d'essai) ou achat unique 59,99 $. Gérez dans Réglages > identifiant Apple > Abonnements.
Confidentialité : https://jackwallner.github.io/quitzyn/privacy-policy.html
Conditions : https://www.apple.com/legal/internet-services/itunes/dev/stdeula/""",
    "fr-CA": """Quit Zyn rend la vie sans nicotine simple et motivante. Comptez chaque jour sans sachets, faites un check-in quotidien et regardez un jardin virtuel grandir avec votre série. Tout reste privé sur votre appareil. Aucun compte requis.

GRATUIT
• Compteur de jours sans nicotine
• Check-in quotidien
• Calendrier et jardin virtuel
• Widgets et Apple Watch

BLOOM+ (OPTIONNEL)
Timeline santé, journal, succès, économies, plus d'espèces. Essai gratuit offert.

Téléchargement gratuit. Bloom+ en tout temps.

Abonnement : mensuel 4,99 $ / annuel 29,99 $ (7 jours d'essai) ou achat unique 59,99 $.
Confidentialité : https://jackwallner.github.io/quitzyn/privacy-policy.html""",
    "es-ES": """Quit Zyn hace que dejar la nicotina sea simple y motivador. Cuenta cada día sin bolsitas, haz un check-in diario y mira crecer un jardín virtual con tu racha. Ya sea Zyn, snus, vape o tabaco, todo es privado en tu dispositivo. Sin cuenta.

TU PROGRESO (GRATIS)
• Contador de días, horas y racha más larga
• Check-in diario con un toque
• Calendario de días sin nicotina
• Hitos a medida que sumas días

JARDÍN QUE CRECE (GRATIS)
• Jardín virtual que florece cada día sin nicotina

WIDGETS Y APPLE WATCH (GRATIS)
• Widgets en pantalla de inicio y bloqueo
• Compañero en Apple Watch

PRIVADO
• Datos solo en tu dispositivo. Sin cuenta, sin anuncios, sin rastreo.

BLOOM+ (OPCIONAL)
Línea de recuperación completa, diario, logros, ahorros, más especies. Prueba gratis para nuevos suscriptores.

Descarga gratis. Mejora a Bloom+ cuando quieras.

Suscripción: Bloom+ mensual 4,99 $ / anual 29,99 $ (7 días de prueba) o compra única 59,99 $.
Privacidad: https://jackwallner.github.io/quitzyn/privacy-policy.html""",
    "es-MX": """Quit Zyn hace simple dejar la nicotina. Cuenta días sin bolsitas, check-in diario y un jardín virtual que crece con tu racha. Privado en tu dispositivo. Sin cuenta.

GRATIS
• Contador de días sin nicotina
• Check-in y calendario
• Jardín virtual
• Widgets y Apple Watch

BLOOM+ (OPCIONAL)
Salud, diario, logros, ahorros, más jardín. Prueba gratis.

Descarga gratis. Bloom+ cuando quieras.

Suscripción: mensual 4,99 $ / anual 29,99 $ (7 días de prueba) o 59,99 $ de por vida.
Privacidad: https://jackwallner.github.io/quitzyn/privacy-policy.html""",
    "ja": """Quit Zyn（クィットザン）は、ニコチンフリーの毎日をシンプルに続けるためのアプリです。ポーチなしの日数をカウントし、毎日チェックインして、連続記録とともに育つバーチャルガーデンを眺められます。Zyn、スヌース、ニコチンポーチ、噛みタバコ、ベイプのどれをやめても、データは端末内にのみ保存されます。アカウント不要。

無料で使える機能
• 日数・時間・最長連続のカウンター
• ワンタップのデイリーチェックイン
• ニコチンフリー日のカレンダー
• 節目のマイルストーン

育つガーデン（無料）
• ニコチンフリーな日ごとに花開くバーチャルガーデン

ウィジェットとApple Watch（無料）
• ホーム画面・ロック画面ウィジェット
• Apple Watchコンパニオン

プライバシー
• データは端末内のみ。アカウント不要、広告なし、追跡なし。

Bloom+（任意）
回復タイムライン、ジャーナル、実績、節約額、追加の樹種。新規購読者向け無料トライアルあり。

無料ダウンロード。いつでもBloom+にアップグレード。

サブスクリプション：月額4.99ドル／年額29.99ドル（7日間無料トライアル）または買い切り59.99ドル。
プライバシーポリシー：https://jackwallner.github.io/quitzyn/privacy-policy.html""",
    "ko": """Quit Zyn은 니코틴 없는 하루를 쉽고 동기부여되게 이어가도록 돕습니다. 파우치 없는 날을 세고, 매일 체크인하며, 연속 기록과 함께 자라는 가상 정원을 지켜보세요. Zyn, 스누스, 니코틴 파우치, 치킹, 베이프를 끊든 모두 기기 안에만 저장됩니다. 계정 불필요.

무료 기능
• 일수, 시간, 최장 연속 카운터
• 원탭 일일 체크인
• 니코틴 프리 날짜 캘린더
• 마일스톤 알림

함께 자라는 정원 (무료)
• 니코틴 프리 하루마다 피어나는 가상 정원

위젯 및 Apple Watch (무료)
• 홈 화면 및 잠금 화면 위젯
• Apple Watch 동반 앱

프라이버시
• 데이터는 기기에만 저장. 계정·광고·추적 없음.

Bloom+ (선택)
회복 타임라인, 일기, 업적, 절약액, 추가 수종. 신규 구독자 무료 체험.

무료 다운로드. 언제든 Bloom+ 업그레이드.

구독: 월 $4.99 / 연 $29.99 (7일 무료 체험) 또는 평생 $59.99.
개인정보: https://jackwallner.github.io/quitzyn/privacy-policy.html""",
    "zh-Hans": """Quit Zyn 让无烟碱生活变得简单而有动力。记录每一个不吃尼古丁袋的日子，每日打卡一次，看着虚拟花园随连续天数成长。无论你是戒 Zyn、唇烟、尼古丁袋、嚼烟还是电子烟，数据都只保存在你的设备上，无需账号。

免费功能
• 显示天数、小时和最长连续的天数计数器
• 一键每日打卡
• 无烟碱日历一览
• 里程碑提醒

与你一起成长的花园（免费）
• 每个无烟碱日都会绽放的虚拟花园

小组件与 Apple Watch（免费）
• 主屏幕与锁定屏幕小组件
• Apple Watch 伴侣应用

隐私设计
• 数据仅存于设备。无需账号、无广告、无追踪。

Bloom+（可选）
完整恢复时间线、日记、成就、节省统计、更多树种。新订阅者可享免费试用。

免费下载，随时升级 Bloom+。

订阅：月付 $4.99 / 年付 $29.99（7 天免费试用）或一次性 $59.99。
隐私政策：https://jackwallner.github.io/quitzyn/privacy-policy.html""",
    "zh-Hant": """Quit Zyn 讓無菸鹼生活變得簡單而有動力。記錄每一個不吃尼古丁袋的日子，每日打卡一次，看著虛擬花園隨連續天數成長。無論你是戒 Zyn、唇煙、尼古丁袋、嚼煙還是電子煙，資料都只保存在你的裝置上，無需帳號。

免費功能
• 顯示天數、小時和最長連續的天數計數器
• 一鍵每日打卡
• 無菸鹼日曆一覽
• 里程碑提醒

與你一起成長的花園（免費）
• 每個無菸鹼日都會綻放的虛擬花園

小工具與 Apple Watch（免費）
• 主畫面與鎖定畫面小工具
• Apple Watch 夥伴 App

隱私設計
• 資料僅存於裝置。無需帳號、無廣告、無追蹤。

Bloom+（選用）
完整恢復時間軸、日記、成就、節省統計、更多樹種。新訂閱者可享免費試用。

免費下載，隨時升級 Bloom+。

訂閱：月付 $4.99 / 年付 $29.99（7 天免費試用）或一次性 $59.99。
隱私權政策：https://jackwallner.github.io/quitzyn/privacy-policy.html""",
}

# Shorter native descriptions for remaining locales (still fully translated, not EN fallback)
def _short_desc(intro: str, free_bullets: str, bloom: str) -> str:
    return f"""{intro}

GRATUIT / FREE
{free_bullets}

BLOOM+ (OPTIONNEL)
{bloom}

Téléchargement gratuit. Essai Bloom+ offert aux nouveaux abonnés.
Privacy: https://jackwallner.github.io/quitzyn/privacy-policy.html"""


# Fill descriptions for locales not explicitly listed above
_FALLBACK_INTROS: dict[str, str] = {
    "ca": "Quit Zyn fa que deixar la nicotina sigui simple. Compta dies sense bosses, check-in diari i un jardí virtual que creix amb la teva ratxa. Tot privat al dispositiu.",
    "it": "Quit Zyn rende semplice restare senza nicotina. Conta ogni giorno senza bustine, fai il check-in quotidiano e guarda crescere un giardino virtuale con la tua serie. Tutto privato sul dispositivo.",
    "pt-BR": "O Quit Zyn torna simples viver sem nicotina. Conte cada dia sem saquinhos, faça check-in diário e veja um jardim virtual crescer com sua sequência. Tudo privado no dispositivo.",
    "pt-PT": "O Quit Zyn torna simples viver sem nicotina. Conte cada dia sem saquinhos, check-in diário e um jardim virtual que cresce com a sua sequência. Privado no dispositivo.",
    "nl-NL": "Quit Zyn maakt nikotinvrij leven eenvoudig. Tel elke dag zonder zakjes, check dagelijks in en zie een virtuele tuin groeien met je reeks. Alles privé op je apparaat.",
    "pl": "Quit Zyn ułatwia życie bez nikotyny. Licz każdy dzień bez saszetek, codzienny check-in i wirtualny ogród rosnący z twoją serią. Wszystko prywatnie na urządzeniu.",
    "sv": "Quit Zyn gör det enkelt att vara nikotinfri. Räkna varje dag utan prillor, daglig check-in och en virtuell trädgård som växer med din serie. Privat på enheten.",
    "da": "Quit Zyn gør det nemt at være nikotinfri. Tæl hver dag uden poser, dagligt check-in og en virtuel have der vokser med din stime. Privat på enheden.",
    "no": "Quit Zyn gjør det enkelt å være nikotinfri. Tell hver dag uten poser, daglig innsjekk og en virtuell hage som vokser med serien din. Privat på enheten.",
    "fi": "Quit Zyn tekee nikotiinittömästä elämästä helppoa. Laske jokainen päivä ilman nauhoja, päivittäinen check-in ja virtuaalinen puutarha kasvaa putkesi mukana.",
    "cs": "Quit Zyn usnadňuje život bez nikotinu. Počítejte dny bez sáčků, denní check-in a virtuální zahrada roste s vaší sérií. Soukromě v zařízení.",
    "sk": "Quit Zyn uľahčuje život bez nikotínu. Počítajte dni bez vreciek, denný check-in a virtuálna záhrada rastie s vašou sériou. Súkromne v zariadení.",
    "hu": "A Quit Zyn egyszerűvé teszi a nikotinmentes életet. Számolj minden tasak nélküli napot, napi check-in és virtuális kert növekszik a sorozatoddal.",
    "ro": "Quit Zyn face simplu viața fără nicotină. Numără fiecare zi fără plicuri, check-in zilnic și o grădină virtuală care crește cu seria ta.",
    "hr": "Quit Zyn olakšava život bez nikotina. Broji svaki dan bez vrećica, dnevni check-in i virtualni vrt raste s tvojom serijom.",
    "el": "Το Quit Zyn κάνει απλή τη ζωή χωρίς νικοτίνη. Μέτρα κάθε μέρα χωρίς φακελάκια, καθημερινό check-in και εικονικός κήπος που μεγαλώνει με τη σειρά σου.",
    "sl-SI": "Quit Zyn poenostavi življenje brez nikotina. Štej vsak dan brez vrečk, dnevni check-in in virtualni vrt raste s tvojo serijo.",
    "tr": "Quit Zyn nikotinsiz yaşamı kolaylaştırır. Poşetsiz her günü say, günlük check-in yap ve serinle büyüyen sanal bahçeyi izle.",
    "ru": "Quit Zyn упрощает жизнь без никотина. Считайте каждый день без пакетиков, ежедневный check-in и виртуальный сад растёт вместе с серией.",
    "uk": "Quit Zyn спрощує життя без нікотину. Рахуйте кожен день без пакетиків, щоденний check-in і віртуальний сад росте разом із серією.",
    "ar-SA": "كيت زين يجعل الحياة بلا نيكوتين بسيطة. عد كل يوم بلا أكياس، تسجيل يومي وحديقة افتراضية تنمو مع سلسلتك. خاص على جهازك.",
    "he": "קוויט זין הופך חיים ללא ניקוטין לפשוטים. ספר כל יום בלי שקיות, צ'ק-אין יומי וגינה וירטואלית שגדלה עם הרצף שלך.",
    "hi": "क्विट ज़िन निकोटीन मुक्त जीवन को आसान बनाता है। हर पाउच-मुक्त दिन गिनें, दैनिक चेक-इन करें और अपनी स्ट्रीक के साथ बढ़ता आभासी बगीचा देखें।",
    "bn-BD": "কুইট জিন নিকোটিন মুক্ত জীবন সহজ করে। প্রতিটি পাউচ-মুক্ত দিন গণনা করুন, দৈনিক চেক-ইন করুন এবং আপনার ধারার সাথে বাড়তে থাকা ভার্চুয়াল বাগান দেখুন।",
    "gu-IN": "ક્વિટ ઝિન નિકોટિન મુક્ત જીવન સરળ બનાવે છે. દરેક પાઉચ-મુક્ત દિવસ ગણો, દૈનિક ચેક-ઇન કરો અને તમારી શ્રેણી સાથે વધતો વર્ચ્યુઅલ બગીચો જુઓ.",
    "kn-IN": "ಕ್ವಿಟ್ ಜಿನ್ ನಿಕೋಟಿನ್ ಮುಕ್ತ ಜೀವನವನ್ನು ಸರಳಗೊಳಿಸುತ್ತದೆ. ಪ್ರತಿ ಪಾಉಚ್-ಮುಕ್ತ ದಿನವನ್ನು ಎಣಿಸಿ, ದೈನಂದಿನ ಚೆಕ್-ಇನ್ ಮಾಡಿ ಮತ್ತು ನಿಮ್ಮ ಸರಣಿಯೊಂದಿಗೆ ಬೆಳೆಯುವ ವರ್ಚುವಲ್ ತೋಟವನ್ನು ನೋಡಿ.",
    "ml-IN": "ക്വിറ്റ് സിൻ നിക്കോട്ടിൻ ഫ്രീ ജീവിതം എളുപ്പമാക്കുന്നു. ഓരോ പൗച്ച്-ഫ്രീ ദിവസവും എണ്ണുക, ദൈനം ചെക്ക്-ഇൻ ചെയ്യുക, നിങ്ങളുടെ സീരീസിനൊപ്പം വളരുന്ന വെർച്വൽ ഗാർഡൻ കാണുക.",
    "mr-IN": "क्विट झिन निकोटीन मुक्त जीवन सोपे करते. प्रत्येक पाउच-मुक्त दिवस मोजा, दैनिक चेक-इन करा आणि तुमच्या मालिकेसह वाढणारा आभासी बाग पहा.",
    "or-IN": "କ୍ୱିଟ ଜିନ ନିକୋଟିନ ମୁକ୍ତ ଜୀବନକୁ ସହଜ କରେ। ପ୍ରତି ପାଉଚ-ମୁକ୍ତ ଦିନ ଗଣନା କରନ୍ତୁ, ଦୈନିକ ଚେକ-ଇନ୍ କରନ୍ତୁ ଏବଂ ଆପଣଙ୍କ ଧାରା ସହ ବଢୁଥିବା ଭର୍ଚୁଆଲ୍ ବଗିଚା ଦେଖନ୍ତୁ।",
    "pa-IN": "ਕਵਿਟ ਜ਼ਿਨ ਨਿਕੋਟੀਨ ਮੁਕਤ ਜੀਵਨ ਨੂੰ ਸਰਲ ਬਣਾਉਂਦਾ ਹੈ। ਹਰ ਪਾਊਚ-ਮੁਕਤ ਦਿਨ ਗਿਣੋ, ਰੋਜ਼ਾਨਾ ਚੈਕ-ਇਨ ਕਰੋ ਅਤੇ ਆਪਣੀ ਲੜੀ ਨਾਲ ਵਧਦਾ ਵਰਚੁਅਲ ਬਾਗ ਦੇਖੋ।",
    "ta-IN": "க்விட் ஸின் நிக்கோட்டின் இல்லா வாழ்க்கையை எளிதாக்குகிறது. ஒவ்வொரு பவுச்-இல்லா நாளையும் எண்ணுங்கள், தினசரி செக்-இன் செய்து உங்கள் தொடருடன் வளரும் மெய்நிகர் தோட்டத்தைப் பாருங்கள்.",
    "te-IN": "క్విట్ జిన్ నికోటిన్ ఫ్రీ జీవితాన్ని సులభం చేస్తుంది. ప్రతి పౌచ్-ఫ్రీ రోజును లెక్కించండి, రోజువారీ చెక్-ఇన్ చేసి మీ సిరీస్‌తో పెరిగే వర్చువల్ తోటను చూడండి.",
    "ur-PK": "کوئٹ زِن نکوٹین سے پاک زندگی آسان بناتا ہے۔ ہر پاؤچ سے پاک دن گنیں، روزانہ چیک اِن کریں اور اپنی سلسلے کے ساتھ بڑھتا ورچوئل باغ دیکھیں۔",
    "th": "ควิตซิน ทำให้ชีวิตปลอดนิโคตินง่ายขึ้น นับทุกวันที่ไม่มีซอง เช็คอินรายวัน และสวนเสมือนที่เติบโตตามสตรีคของคุณ",
    "vi": "Quit Zyn giúp sống không nicotin đơn giản. Đếm mỗi ngày không túi, check-in hàng ngày và vườn ảo lớn lên cùng chuỗi ngày của bạn.",
    "id": "Quit Zyn membuat hidup bebas nikotin jadi sederhana. Hitung setiap hari tanpa kantong, check-in harian, dan kebun virtual tumbuh dengan rangkaian Anda.",
    "ms": "Quit Zyn memudahkan hidup bebas nikotin. Kira setiap hari tanpa kantung, daftar masuk harian dan taman maya berkembang dengan rentetan anda.",
}

_FREE = """• Day counter, daily check-in, nicotine-free calendar
• Virtual garden that grows with your streak
• Home Screen, Lock Screen widgets and Apple Watch
• Private on device. No account, no ads, no tracking."""

_BLOOM = """Full nicotine recovery timeline, journal, achievements, savings, more garden species. Free trial for new subscribers. Monthly $4.99 / Yearly $29.99 / Lifetime $59.99."""

for loc, intro in _FALLBACK_INTROS.items():
    if loc not in DESCRIPTIONS:
        DESCRIPTIONS[loc] = f"{intro}\n\n{_FREE}\n\nBLOOM+ (OPTIONAL)\n{_BLOOM}\n\nPrivacy: https://jackwallner.github.io/quitzyn/privacy-policy.html"

PROMOTIONAL: dict[str, str] = {}
RELEASE_NOTES: dict[str, str] = {}


def load_locale_extras() -> None:
    """Override descriptions and add promotional/release notes from adapted Sober copy."""
    if not EXTRAS_PATH.exists():
        return
    extras = json.loads(EXTRAS_PATH.read_text(encoding="utf-8"))
    for loc, desc in extras.get("descriptions", {}).items():
        if loc in CORE:
            DESCRIPTIONS[loc] = desc.strip()
    PROMOTIONAL.clear()
    PROMOTIONAL.update(extras.get("promotional", {}))
    RELEASE_NOTES.clear()
    RELEASE_NOTES.update(extras.get("release_notes", {}))


load_locale_extras()


def validate() -> list[str]:
    errs: list[str] = []
    supported = json.loads((Path(__file__).parent / "asc-supported-locales.json").read_text())["locales"]
    missing = set(supported) - set(CORE)
    extra = set(CORE) - set(supported)
    if missing:
        errs.append(f"missing locales in CORE: {sorted(missing)}")
    if extra:
        errs.append(f"extra locales in CORE: {sorted(extra)}")
    for loc, (name, sub, kw) in CORE.items():
        for label, val, lim in [("name", name, 30), ("subtitle", sub, 30), ("keywords", kw, 100)]:
            if len(val) > lim:
                errs.append(f"{loc} {label} {len(val)}>{lim}: {val!r}")
    for loc in CORE:
        if loc not in DESCRIPTIONS:
            errs.append(f"missing description for {loc}")
        if loc not in PROMOTIONAL:
            errs.append(f"missing promotional for {loc}")
        if loc not in RELEASE_NOTES:
            errs.append(f"missing release_notes for {loc}")
        if len(PROMOTIONAL.get(loc, "")) > 170:
            errs.append(f"{loc} promotional {len(PROMOTIONAL[loc])}>170")
    return errs


def emit_py() -> str:
    lines = [
        '#!/usr/bin/env python3',
        '"""Native App Store copy for all 50 ASC locales (Quit Zyn). Source of truth."""',
        "from __future__ import annotations",
        "",
        "LOCALES: dict[str, dict[str, str]] = {",
    ]
    for loc in sorted(CORE):
        name, sub, kw = CORE[loc]
        desc = DESCRIPTIONS[loc]
        lines.append(f'    "{loc}": {{')
        lines.append(f'        "name": {json.dumps(name, ensure_ascii=False)},')
        lines.append(f'        "subtitle": {json.dumps(sub, ensure_ascii=False)},')
        lines.append(f'        "keywords": {json.dumps(kw, ensure_ascii=False)},')
        lines.append(f'        "description": {json.dumps(desc, ensure_ascii=False)},')
        lines.append(f'        "promotional": {json.dumps(PROMOTIONAL[loc], ensure_ascii=False)},')
        lines.append(f'        "release_notes": {json.dumps(RELEASE_NOTES[loc], ensure_ascii=False)},')
        lines.append("    },")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    errs = validate()
    if errs:
        for e in errs:
            print("ERROR:", e)
        return 1
    OUT.write_text(emit_py(), encoding="utf-8")
    print(f"Wrote {OUT} ({len(CORE)} locales)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
