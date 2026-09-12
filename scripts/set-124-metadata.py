#!/usr/bin/env python3
"""1.2.4 listing: What's New in all 50 locales, and clean localized descriptions.

The 46 non-English descriptions were machine-forked from the alcohol app and
still carried sobriety and drinking words (tr listed an "Alkolsüz gün sayacı"),
em-dash replacement artifacts (" ,  "), mangled words ("bez nikotynyym"), listed
the free Apple Watch and widgets under Bloom+, and had no subscription terms or
disclaimer. They are rebuilt here from one template per locale, keeping each
locale's existing Terms/Privacy link lines verbatim.

English keeps its long description with three edits: the watch does not check
in, craving mode and slips are added, and Bloom+ leads with patterns.

  python3 scripts/set-124-metadata.py            # dry run: validate + print sizes
  python3 scripts/set-124-metadata.py --apply    # write fastlane files + PATCH ASC
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import asc_lib as L

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "fastlane/metadata"
VERSION = "1.2.4"
BUNDLE = "com.jackwallner.quitzyn"

EN_WHATS_NEW = (
    "New: craving mode. When an urge hits, start a short guided breathing session and ride it out. It's free.\n"
    "A slip no longer wipes out your garden. Your counter restarts, your tree keeps half its growth, and a mistaken slip can be undone.\n"
    "Bloom+ now shows your craving patterns.\n"
    "Widgets and Apple Watch now match your tree, plus other fixes."
)

EN_CRAVING_SECTION = (
    "WHEN A CRAVING HITS (FREE)\n"
    "- Craving mode: a short guided breathing session to ride out an urge.\n"
    "- Note what set it off, if you want to.\n"
    "- A slip doesn't erase your garden. Your counter restarts honestly, your tree keeps half its growth, and a mistaken slip can be undone.\n\n"
)

EN_DISCLAIMER = "Quit Zyn is a self-tracking tool, not medical advice.\n\n"

# locale: (intro, free heading, 7 free bullets, plus heading, 5 plus bullets,
#          subscription terms, disclaimer, what's new)
T: dict[str, tuple] = {
    "ar-SA": (
        "يساعدك Quit Zyn على البقاء خاليًا من النيكوتين بعدّاد للأيام وتسجيل يومي وحديقة افتراضية تنمو مع كل يوم بلا نيكوتين. لمن يقلع عن Zyn والسنوس وأكياس النيكوتين والتدخين الإلكتروني.",
        "مجانًا",
        ["عدّاد أيام بلا نيكوتين وأطول سلسلة", "تسجيل يومي وتقويم", "حديقة افتراضية تنمو معك", "وضع الرغبة الشديدة: جلسة تنفّس موجّهة لتجاوز الرغبة", "الانتكاسة لا تمحو حديقتك", "Apple Watch وأدوات الشاشة الرئيسية", "خاص على جهازك، بلا حساب"],
        "BLOOM+ (اختياري)",
        ["أنماط رغباتك الشديدة", "خط زمني صحي كامل مع المصادر", "يوميات مع أسئلة موجّهة", "إنجازات ومحطات", "المال والأكياس التي وفّرتها"],
        "يتوفر Bloom+ كاشتراك شهري أو سنوي يتجدد تلقائيًا، وكلاهما مع تجربة مجانية لمدة أسبوع للمشتركين الجدد المؤهلين، أو كشراء مدى الحياة لمرة واحدة. تُعرض الأسعار في التطبيق قبل الشراء وتختلف حسب المنطقة. يُحصَّل المبلغ من حساب Apple ID عند التأكيد. يتجدد الاشتراك تلقائيًا ما لم يُلغَ قبل 24 ساعة على الأقل من نهاية الفترة. يمكنك الإدارة أو الإلغاء من إعدادات حسابك في App Store.",
        "Quit Zyn أداة لتتبّع تقدمك الذاتي وليس نصيحة طبية.",
        "جديد: وضع الرغبة الشديدة. عندما تشتد الرغبة، ابدأ جلسة تنفّس موجّهة قصيرة مجانًا.\nالانتكاسة لم تعد تمحو حديقتك: يبدأ العدّاد من جديد وتحتفظ شجرتك بنصف نموها، ويمكن التراجع عن انتكاسة سُجّلت بالخطأ.\nيعرض Bloom+ الآن أنماط رغباتك.\nأدوات الشاشة الرئيسية وApple Watch تطابق شجرتك الآن، مع إصلاحات أخرى.",
    ),
    "bn-BD": (
        "Quit Zyn দিন গণনা, দৈনিক চেক-ইন এবং প্রতিটি নিকোটিন-মুক্ত দিনে বেড়ে ওঠা একটি ভার্চুয়াল বাগান দিয়ে আপনাকে নিকোটিন-মুক্ত থাকতে সাহায্য করে। Zyn, স্নাস, নিকোটিন পাউচ ও ভেপিং ছাড়ার জন্য।",
        "বিনামূল্যে",
        ["নিকোটিন-মুক্ত দিন গণনা ও দীর্ঘতম ধারা", "দৈনিক চেক-ইন ও ক্যালেন্ডার", "আপনার সাথে বেড়ে ওঠা ভার্চুয়াল বাগান", "ক্রেভিং মোড: তাড়না পার করতে নির্দেশিত শ্বাস-প্রশ্বাস সেশন", "একটি স্লিপ আপনার বাগান মুছে দেয় না", "Apple Watch ও হোম স্ক্রিন উইজেট", "ডিভাইসে ব্যক্তিগত, অ্যাকাউন্ট লাগে না"],
        "BLOOM+ (ঐচ্ছিক)",
        ["আপনার ক্রেভিংয়ের ধরন", "উৎসসহ সম্পূর্ণ স্বাস্থ্য টাইমলাইন", "প্রম্পটসহ ডায়েরি", "অর্জন ও মাইলফলক", "সাশ্রয় করা টাকা ও পাউচ"],
        "Bloom+ মাসিক বা বার্ষিক স্বয়ংক্রিয়-নবায়নযোগ্য সাবস্ক্রিপশন হিসেবে পাওয়া যায়, যোগ্য নতুন গ্রাহকদের জন্য দুটিতেই ১ সপ্তাহের বিনামূল্যে ট্রায়াল, অথবা এককালীন লাইফটাইম ক্রয় হিসেবে। কেনার আগে অ্যাপে দাম দেখানো হয় এবং অঞ্চলভেদে ভিন্ন হয়। নিশ্চিত করার সময় আপনার Apple ID থেকে অর্থ নেওয়া হয়। মেয়াদ শেষ হওয়ার অন্তত ২৪ ঘণ্টা আগে বাতিল না করলে সাবস্ক্রিপশন স্বয়ংক্রিয়ভাবে নবায়ন হয়। App Store অ্যাকাউন্ট সেটিংসে পরিচালনা বা বাতিল করুন।",
        "Quit Zyn নিজের অগ্রগতি ট্র্যাক করার একটি টুল, চিকিৎসা পরামর্শ নয়।",
        "নতুন: ক্রেভিং মোড। তাড়না এলে বিনামূল্যে একটি ছোট নির্দেশিত শ্বাস-প্রশ্বাস সেশন শুরু করুন।\nস্লিপ আর আপনার বাগান মুছে দেয় না: কাউন্টার আবার শুরু হয়, গাছ তার অর্ধেক বৃদ্ধি রাখে, এবং ভুল করে লগ করা স্লিপ ফিরিয়ে নেওয়া যায়।\nBloom+ এখন আপনার ক্রেভিংয়ের ধরন দেখায়।\nউইজেট ও Apple Watch এখন আপনার গাছের সাথে মেলে, সাথে আরও সংশোধন।",
    ),
    "ca": (
        "Quit Zyn t'ajuda a mantenir-te sense nicotina amb un comptador de dies, un check-in diari i un jardí virtual que creix amb cada dia sense nicotina. Per deixar el Zyn, el snus, les bossetes de nicotina i el vapeig.",
        "GRATUÏT",
        ["Comptador de dies sense nicotina i ratxa més llarga", "Check-in diari i calendari", "Jardí virtual que creix amb tu", "Mode desig: una respiració guiada per superar l'impuls", "Una recaiguda no esborra el teu jardí", "Apple Watch i widgets de pantalla d'inici", "Privat al dispositiu, sense compte"],
        "BLOOM+ (OPCIONAL)",
        ["Els teus patrons de desig", "Cronologia de salut completa amb fonts", "Diari amb suggeriments", "Assoliments i fites", "Diners i bossetes estalviats"],
        "Bloom+ està disponible com a subscripció mensual o anual amb renovació automàtica, totes dues amb una prova gratuïta d'1 setmana per a nous subscriptors aptes, o com a compra única de per vida. Els preus es mostren a l'app abans de comprar i varien segons la regió. El pagament es carrega al teu Apple ID en confirmar. La subscripció es renova automàticament tret que es cancel·li almenys 24 hores abans del final del període. Gestiona-la o cancel·la-la a la configuració del teu compte de l'App Store.",
        "Quit Zyn és una eina de seguiment personal, no un consell mèdic.",
        "Novetat: mode desig. Quan arribi un impuls, comença gratis una breu respiració guiada.\nUna recaiguda ja no esborra el teu jardí: el comptador es reinicia, l'arbre conserva la meitat del creixement i pots desfer una recaiguda registrada per error.\nBloom+ ara mostra els teus patrons de desig.\nEls widgets i l'Apple Watch ara coincideixen amb el teu arbre, i altres correccions.",
    ),
    "cs": (
        "Quit Zyn vám pomůže zůstat bez nikotinu díky počítadlu dní, dennímu check-inu a virtuální zahradě, která roste s každým dnem bez nikotinu. Pro odvykání Zynu, snusu, nikotinových sáčků a vapování.",
        "ZDARMA",
        ["Počítadlo dní bez nikotinu a nejdelší série", "Denní check-in a kalendář", "Virtuální zahrada, která roste s vámi", "Režim chuti: řízené dýchání k překonání nutkání", "Uklouznutí nesmaže vaši zahradu", "Apple Watch a widgety na plochu", "Soukromě v zařízení, bez účtu"],
        "BLOOM+ (VOLITELNÉ)",
        ["Vzorce vašich chutí", "Úplná zdravotní časová osa se zdroji", "Deník s podněty", "Úspěchy a milníky", "Ušetřené peníze a sáčky"],
        "Bloom+ je k dispozici jako měsíční nebo roční automaticky obnovované předplatné, obě s týdenní zkušební verzí zdarma pro nové oprávněné předplatitele, nebo jako jednorázový doživotní nákup. Ceny se zobrazují v aplikaci před nákupem a liší se podle regionu. Platba se strhne z vašeho Apple ID při potvrzení. Předplatné se automaticky obnoví, pokud jej nezrušíte alespoň 24 hodin před koncem období. Spravovat nebo zrušit jej můžete v nastavení účtu App Store.",
        "Quit Zyn je nástroj pro sledování vlastního pokroku, nikoli lékařská rada.",
        "Novinka: režim chuti. Když přijde nutkání, spusťte zdarma krátké řízené dýchání.\nUklouznutí už nesmaže vaši zahradu: počítadlo začne znovu, strom si ponechá polovinu růstu a omylem zadané uklouznutí lze vrátit.\nBloom+ nyní ukazuje vzorce vašich chutí.\nWidgety a Apple Watch nyní odpovídají vašemu stromu, plus další opravy.",
    ),
    "da": (
        "Quit Zyn hjælper dig med at forblive nikotinfri med en dagtæller, en daglig check-in og en virtuel have, der vokser for hver nikotinfri dag. Til dig, der stopper med Zyn, snus, nikotinposer og vape.",
        "GRATIS",
        ["Nikotinfri dagtæller og længste stime", "Daglig check-in og kalender", "Virtuel have, der vokser med dig", "Trangtilstand: en guidet vejrtrækningsøvelse til at komme gennem trangen", "Et tilbagefald sletter ikke din have", "Apple Watch og widgets til hjemmeskærmen", "Privat på enheden, ingen konto"],
        "BLOOM+ (VALGFRIT)",
        ["Dine trangmønstre", "Fuld sundhedstidslinje med kilder", "Dagbog med spørgsmål", "Præstationer og milepæle", "Sparede penge og poser"],
        "Bloom+ fås som et månedligt eller årligt abonnement med automatisk fornyelse, begge med en gratis prøveperiode på 1 uge for kvalificerede nye abonnenter, eller som et engangskøb for livstid. Priserne vises i appen, før du køber, og varierer efter område. Betalingen trækkes på dit Apple-id ved bekræftelse. Abonnementet fornyes automatisk, medmindre det opsiges mindst 24 timer før periodens udløb. Administrer eller opsig i indstillingerne for din App Store-konto.",
        "Quit Zyn er et værktøj til at følge dine egne fremskridt, ikke medicinsk rådgivning.",
        "Nyt: trangtilstand. Når trangen melder sig, kan du gratis starte en kort guidet vejrtrækningsøvelse.\nEt tilbagefald sletter ikke længere din have: tælleren starter forfra, træet beholder halvdelen af sin vækst, og et fejlregistreret tilbagefald kan fortrydes.\nBloom+ viser nu dine trangmønstre.\nWidgets og Apple Watch matcher nu dit træ, plus rettelser.",
    ),
    "de-DE": (
        "Quit Zyn hilft dir, nikotinfrei zu bleiben, mit Tageszähler, täglichem Check-in und einem virtuellen Garten, der mit jedem nikotinfreien Tag wächst. Für alle, die mit Zyn, Snus, Nikotinbeuteln oder Vapes aufhören.",
        "KOSTENLOS",
        ["Nikotinfreier Tageszähler und längste Serie", "Täglicher Check-in und Kalender", "Virtueller Garten, der mit dir wächst", "Craving-Modus: eine geführte Atemübung, um das Verlangen auszusitzen", "Ein Rückfall löscht deinen Garten nicht", "Apple Watch und Home-Bildschirm-Widgets", "Privat auf dem Gerät, kein Konto nötig"],
        "BLOOM+ (OPTIONAL)",
        ["Deine Verlangensmuster", "Vollständige Gesundheits-Timeline mit Quellen", "Tagebuch mit Impulsen", "Erfolge und Meilensteine", "Gespartes Geld und Beutel"],
        "Bloom+ gibt es als monatliches oder jährliches, sich automatisch verlängerndes Abo, beide mit einer 1-wöchigen Gratistestphase für berechtigte Neukunden, oder als einmaligen Lifetime-Kauf. Die Preise werden vor dem Kauf in der App angezeigt und variieren je nach Region. Die Zahlung wird bei Bestätigung über deine Apple-ID abgerechnet. Das Abo verlängert sich automatisch, wenn es nicht mindestens 24 Stunden vor Ende des Zeitraums gekündigt wird. Verwalten oder kündigen kannst du es in den Einstellungen deines App Store-Accounts.",
        "Quit Zyn ist ein Werkzeug zur Selbstbeobachtung und keine medizinische Beratung.",
        "Neu: Craving-Modus. Wenn das Verlangen kommt, starte kostenlos eine kurze geführte Atemübung.\nEin Rückfall löscht deinen Garten nicht mehr: Der Zähler beginnt neu, dein Baum behält die Hälfte seines Wachstums, und ein versehentlich eingetragener Rückfall lässt sich rückgängig machen.\nBloom+ zeigt jetzt deine Verlangensmuster.\nWidgets und Apple Watch zeigen jetzt denselben Baum wie die App, dazu weitere Fehlerbehebungen.",
    ),
    "el": (
        "Το Quit Zyn σας βοηθά να μείνετε χωρίς νικοτίνη με μετρητή ημερών, καθημερινό check-in και έναν εικονικό κήπο που μεγαλώνει με κάθε μέρα χωρίς νικοτίνη. Για όσους κόβουν το Zyn, το snus, τα φακελάκια νικοτίνης και το άτμισμα.",
        "ΔΩΡΕΑΝ",
        ["Μετρητής ημερών χωρίς νικοτίνη και μεγαλύτερο σερί", "Καθημερινό check-in και ημερολόγιο", "Εικονικός κήπος που μεγαλώνει μαζί σας", "Λειτουργία λαχτάρας: καθοδηγούμενη αναπνοή για να περάσει η επιθυμία", "Μια υποτροπή δεν σβήνει τον κήπο σας", "Apple Watch και widgets αρχικής οθόνης", "Ιδιωτικό στη συσκευή, χωρίς λογαριασμό"],
        "BLOOM+ (ΠΡΟΑΙΡΕΤΙΚΟ)",
        ["Τα μοτίβα της λαχτάρας σας", "Πλήρες χρονολόγιο υγείας με πηγές", "Ημερολόγιο με ερωτήσεις", "Επιτεύγματα και ορόσημα", "Χρήματα και φακελάκια που γλιτώσατε"],
        "Το Bloom+ διατίθεται ως μηνιαία ή ετήσια συνδρομή με αυτόματη ανανέωση, και οι δύο με δωρεάν δοκιμή 1 εβδομάδας για νέους επιλέξιμους συνδρομητές, ή ως εφάπαξ αγορά εφ' όρου ζωής. Οι τιμές εμφανίζονται στην εφαρμογή πριν από την αγορά και διαφέρουν ανά περιοχή. Η χρέωση γίνεται στο Apple ID σας κατά την επιβεβαίωση. Η συνδρομή ανανεώνεται αυτόματα εκτός αν ακυρωθεί τουλάχιστον 24 ώρες πριν από το τέλος της περιόδου. Διαχείριση ή ακύρωση από τις ρυθμίσεις του λογαριασμού σας στο App Store.",
        "Το Quit Zyn είναι εργαλείο παρακολούθησης της προόδου σας, όχι ιατρική συμβουλή.",
        "Νέο: λειτουργία λαχτάρας. Όταν έρθει η επιθυμία, ξεκινήστε δωρεάν μια σύντομη καθοδηγούμενη αναπνοή.\nΜια υποτροπή δεν σβήνει πια τον κήπο σας: ο μετρητής ξεκινά από την αρχή, το δέντρο κρατά το μισό της ανάπτυξής του και μια υποτροπή που καταγράφηκε κατά λάθος αναιρείται.\nΤο Bloom+ δείχνει πλέον τα μοτίβα της λαχτάρας σας.\nΤα widgets και το Apple Watch ταιριάζουν πλέον με το δέντρο σας, μαζί με διορθώσεις.",
    ),
    "es-ES": (
        "Quit Zyn te ayuda a mantenerte sin nicotina con un contador de días, un check-in diario y un jardín virtual que crece con cada día sin nicotina. Para dejar Zyn, snus, bolsitas de nicotina y el vapeo.",
        "GRATIS",
        ["Contador de días sin nicotina y racha más larga", "Check-in diario y calendario", "Jardín virtual que crece contigo", "Modo antojo: una respiración guiada para dejar pasar las ganas", "Una recaída no borra tu jardín", "Apple Watch y widgets de pantalla de inicio", "Privado en tu dispositivo, sin cuenta"],
        "BLOOM+ (OPCIONAL)",
        ["Tus patrones de antojo", "Cronología de salud completa con fuentes", "Diario con sugerencias", "Logros e hitos", "Dinero y bolsitas ahorrados"],
        "Bloom+ está disponible como suscripción mensual o anual con renovación automática, ambas con una prueba gratuita de 1 semana para nuevos suscriptores que cumplan los requisitos, o como compra única de por vida. Los precios se muestran en la app antes de comprar y varían según la región. El pago se carga a tu Apple ID al confirmar. La suscripción se renueva automáticamente salvo que se cancele al menos 24 horas antes del final del periodo. Gestiona o cancela en los ajustes de tu cuenta del App Store.",
        "Quit Zyn es una herramienta de seguimiento personal, no un consejo médico.",
        "Novedad: modo antojo. Cuando lleguen las ganas, empieza gratis una breve respiración guiada.\nUna recaída ya no borra tu jardín: el contador vuelve a empezar, tu árbol conserva la mitad de su crecimiento y puedes deshacer una recaída registrada por error.\nBloom+ ahora muestra tus patrones de antojo.\nLos widgets y el Apple Watch ahora coinciden con tu árbol, además de correcciones.",
    ),
    "fi": (
        "Quit Zyn auttaa pysymään nikotiinittomana päivälaskurin, päivittäisen kirjauksen ja jokaisena nikotiinittomana päivänä kasvavan virtuaalisen puutarhan avulla. Zynin, nuuskan, nikotiinipussien ja vapettamisen lopettamiseen.",
        "ILMAISEKSI",
        ["Nikotiinittomien päivien laskuri ja pisin putki", "Päivittäinen kirjaus ja kalenteri", "Kanssasi kasvava virtuaalinen puutarha", "Himotila: ohjattu hengitysharjoitus, jonka aikana himo menee ohi", "Retkahdus ei pyyhi puutarhaasi", "Apple Watch ja kotinäytön widgetit", "Yksityinen laitteella, ei tiliä"],
        "BLOOM+ (VALINNAINEN)",
        ["Himojesi toistuvat kuviot", "Täysi terveysaikajana lähteineen", "Päiväkirja kysymyksineen", "Saavutukset ja virstanpylväät", "Säästetyt rahat ja pussit"],
        "Bloom+ on saatavilla kuukausittain tai vuosittain automaattisesti uusiutuvana tilauksena, molemmissa viikon ilmainen kokeilu kelpoisille uusille tilaajille, tai kertaostona elinikäiseen käyttöön. Hinnat näytetään sovelluksessa ennen ostoa, ja ne vaihtelevat alueittain. Maksu veloitetaan Apple ID:stäsi vahvistuksen yhteydessä. Tilaus uusiutuu automaattisesti, ellei sitä peruta vähintään 24 tuntia ennen jakson päättymistä. Hallitse tai peru tilaus App Store -tilisi asetuksissa.",
        "Quit Zyn on oman edistymisen seurantatyökalu, ei lääketieteellinen neuvo.",
        "Uutta: himotila. Kun himo iskee, aloita maksutta lyhyt ohjattu hengitysharjoitus.\nRetkahdus ei enää pyyhi puutarhaasi: laskuri alkaa alusta, puu säilyttää puolet kasvustaan ja vahingossa kirjatun retkahduksen voi perua.\nBloom+ näyttää nyt himojesi kuviot.\nWidgetit ja Apple Watch näyttävät nyt saman puun kuin sovellus, lisäksi korjauksia.",
    ),
    "fr-FR": (
        "Quit Zyn vous aide à rester sans nicotine avec un compteur de jours, un check-in quotidien et un jardin virtuel qui grandit à chaque jour sans nicotine. Pour arrêter Zyn, le snus, les sachets de nicotine et la vape.",
        "GRATUIT",
        ["Compteur de jours sans nicotine et plus longue série", "Check-in quotidien et calendrier", "Jardin virtuel qui grandit avec vous", "Mode envie : une respiration guidée pour laisser passer l'envie", "Un écart n'efface pas votre jardin", "Apple Watch et widgets d'écran d'accueil", "Privé sur l'appareil, aucun compte"],
        "BLOOM+ (OPTIONNEL)",
        ["Vos schémas d'envie", "Chronologie santé complète avec sources", "Journal avec suggestions", "Succès et étapes", "Argent et sachets économisés"],
        "Bloom+ est proposé en abonnement mensuel ou annuel à renouvellement automatique, tous deux avec un essai gratuit d'une semaine pour les nouveaux abonnés éligibles, ou en achat unique à vie. Les prix sont affichés dans l'app avant l'achat et varient selon la région. Le paiement est débité de votre identifiant Apple à la confirmation. L'abonnement se renouvelle automatiquement sauf annulation au moins 24 heures avant la fin de la période. Gérez ou annulez-le dans les réglages de votre compte App Store.",
        "Quit Zyn est un outil de suivi personnel, pas un avis médical.",
        "Nouveau : mode envie. Quand l'envie arrive, lancez gratuitement une courte respiration guidée.\nUn écart n'efface plus votre jardin : le compteur repart de zéro, votre arbre garde la moitié de sa croissance et un écart saisi par erreur peut être annulé.\nBloom+ affiche désormais vos schémas d'envie.\nLes widgets et l'Apple Watch correspondent maintenant à votre arbre, avec d'autres corrections.",
    ),
    "gu-IN": (
        "Quit Zyn દિવસ ગણતરી, દૈનિક ચેક-ઇન અને દરેક નિકોટિન-મુક્ત દિવસે વધતા વર્ચ્યુઅલ બગીચા સાથે તમને નિકોટિન-મુક્ત રહેવામાં મદદ કરે છે. Zyn, સ્નસ, નિકોટિન પાઉચ અને વેપિંગ છોડવા માટે.",
        "મફત",
        ["નિકોટિન-મુક્ત દિવસ કાઉન્ટર અને સૌથી લાંબી શ્રેણી", "દૈનિક ચેક-ઇન અને કેલેન્ડર", "તમારી સાથે વધતો વર્ચ્યુઅલ બગીચો", "ક્રેવિંગ મોડ: ઇચ્છા પસાર કરવા માર્ગદર્શિત શ્વાસ સત્ર", "એક સ્લિપ તમારો બગીચો ભૂંસતી નથી", "Apple Watch અને હોમ સ્ક્રીન વિજેટ", "ઉપકરણ પર ખાનગી, ખાતાની જરૂર નથી"],
        "BLOOM+ (વૈકલ્પિક)",
        ["તમારી ક્રેવિંગની પેટર્ન", "સ્ત્રોતો સાથે સંપૂર્ણ આરોગ્ય ટાઇમલાઇન", "પ્રોમ્પ્ટ સાથે ડાયરી", "સિદ્ધિઓ અને માઇલસ્ટોન", "બચાવેલા પૈસા અને પાઉચ"],
        "Bloom+ માસિક અથવા વાર્ષિક સ્વયં-નવીકરણ થતા સબ્સ્ક્રિપ્શન તરીકે ઉપલબ્ધ છે, બંનેમાં પાત્ર નવા સબ્સ્ક્રાઇબર્સ માટે 1 અઠવાડિયાની મફત ટ્રાયલ, અથવા એક વખતની લાઇફટાઇમ ખરીદી તરીકે. ખરીદી પહેલાં એપમાં કિંમતો બતાવવામાં આવે છે અને પ્રદેશ પ્રમાણે બદલાય છે. પુષ્ટિ વખતે તમારા Apple ID પરથી ચુકવણી લેવાય છે. સમયગાળો પૂરો થવાના ઓછામાં ઓછા 24 કલાક પહેલાં રદ ન કરો તો સબ્સ્ક્રિપ્શન આપમેળે નવીકરણ થાય છે. App Store ખાતાની સેટિંગ્સમાં સંચાલન કરો અથવા રદ કરો.",
        "Quit Zyn પોતાની પ્રગતિ ટ્રેક કરવાનું સાધન છે, તબીબી સલાહ નથી.",
        "નવું: ક્રેવિંગ મોડ. ઇચ્છા જાગે ત્યારે મફતમાં ટૂંકું માર્ગદર્શિત શ્વાસ સત્ર શરૂ કરો.\nસ્લિપ હવે તમારો બગીચો ભૂંસતી નથી: કાઉન્ટર ફરી શરૂ થાય છે, વૃક્ષ તેની અડધી વૃદ્ધિ રાખે છે, અને ભૂલથી નોંધાયેલી સ્લિપ પાછી લઈ શકાય છે.\nBloom+ હવે તમારી ક્રેવિંગની પેટર્ન બતાવે છે.\nવિજેટ અને Apple Watch હવે તમારા વૃક્ષ સાથે મેળ ખાય છે, સાથે અન્ય સુધારા.",
    ),
    "he": (
        "Quit Zyn עוזר לך להישאר בלי ניקוטין עם מונה ימים, צ'ק-אין יומי וגינה וירטואלית שגדלה עם כל יום בלי ניקוטין. למי שמפסיק Zyn, סנוס, שקיקי ניקוטין ווייפ.",
        "בחינם",
        ["מונה ימים בלי ניקוטין והרצף הארוך ביותר", "צ'ק-אין יומי ולוח שנה", "גינה וירטואלית שגדלה איתך", "מצב חשק: תרגול נשימה מודרך כדי לעבור את הדחף", "מעידה לא מוחקת את הגינה שלך", "Apple Watch ווידג'טים למסך הבית", "פרטי במכשיר, בלי חשבון"],
        "BLOOM+ (אופציונלי)",
        ["דפוסי החשק שלך", "ציר זמן בריאותי מלא עם מקורות", "יומן עם שאלות מנחות", "הישגים ואבני דרך", "כסף ושקיקים שחסכת"],
        "Bloom+ זמין כמנוי חודשי או שנתי המתחדש אוטומטית, שניהם עם ניסיון חינם של שבוע למנויים חדשים זכאים, או כרכישה חד-פעמית לכל החיים. המחירים מוצגים באפליקציה לפני הרכישה ומשתנים לפי אזור. החיוב מתבצע ב-Apple ID שלך עם האישור. המנוי מתחדש אוטומטית אלא אם בוטל לפחות 24 שעות לפני סוף התקופה. ניהול או ביטול בהגדרות חשבון ה-App Store שלך.",
        "Quit Zyn הוא כלי למעקב עצמי, ואינו ייעוץ רפואי.",
        "חדש: מצב חשק. כשהדחף מגיע, התחל בחינם תרגול נשימה מודרך קצר.\nמעידה כבר לא מוחקת את הגינה: המונה מתחיל מחדש, העץ שומר על מחצית מהצמיחה, ואפשר לבטל מעידה שנרשמה בטעות.\nBloom+ מציג עכשיו את דפוסי החשק שלך.\nהווידג'טים וה-Apple Watch תואמים עכשיו לעץ שלך, ועוד תיקונים.",
    ),
    "hi": (
        "Quit Zyn दिन गिनती, दैनिक चेक-इन और हर निकोटीन-मुक्त दिन के साथ बढ़ने वाले वर्चुअल बगीचे से आपको निकोटीन-मुक्त रहने में मदद करता है। Zyn, स्नस, निकोटीन पाउच और वेपिंग छोड़ने के लिए।",
        "मुफ़्त",
        ["निकोटीन-मुक्त दिन काउंटर और सबसे लंबी स्ट्रीक", "दैनिक चेक-इन और कैलेंडर", "आपके साथ बढ़ने वाला वर्चुअल बगीचा", "क्रेविंग मोड: तलब को गुज़रने देने के लिए गाइडेड साँस सत्र", "एक चूक आपका बगीचा नहीं मिटाती", "Apple Watch और होम स्क्रीन विजेट", "डिवाइस पर निजी, खाते की ज़रूरत नहीं"],
        "BLOOM+ (वैकल्पिक)",
        ["आपकी तलब के पैटर्न", "स्रोतों के साथ पूरी स्वास्थ्य टाइमलाइन", "प्रॉम्प्ट वाली डायरी", "उपलब्धियाँ और माइलस्टोन", "बचाए गए पैसे और पाउच"],
        "Bloom+ मासिक या वार्षिक स्वतः-नवीनीकृत सब्सक्रिप्शन के रूप में उपलब्ध है, दोनों में पात्र नए सब्सक्राइबर्स के लिए 1 सप्ताह का मुफ़्त ट्रायल, या एक बार की लाइफ़टाइम खरीद के रूप में। खरीदने से पहले ऐप में कीमतें दिखाई जाती हैं और क्षेत्र के अनुसार बदलती हैं। पुष्टि पर आपके Apple ID से भुगतान लिया जाता है। अवधि खत्म होने से कम से कम 24 घंटे पहले रद्द न करने पर सब्सक्रिप्शन अपने आप नवीनीकृत हो जाता है। App Store खाता सेटिंग्स में प्रबंधित या रद्द करें।",
        "Quit Zyn अपनी प्रगति ट्रैक करने का टूल है, चिकित्सा सलाह नहीं।",
        "नया: क्रेविंग मोड। तलब लगे तो मुफ़्त में एक छोटा गाइडेड साँस सत्र शुरू करें।\nचूक अब आपका बगीचा नहीं मिटाती: काउंटर फिर से शुरू होता है, पेड़ अपनी आधी बढ़त रखता है, और गलती से दर्ज चूक वापस ली जा सकती है।\nBloom+ अब आपकी तलब के पैटर्न दिखाता है।\nविजेट और Apple Watch अब आपके पेड़ से मेल खाते हैं, साथ में और सुधार।",
    ),
    "hr": (
        "Quit Zyn pomaže vam ostati bez nikotina uz brojač dana, dnevni check-in i virtualni vrt koji raste sa svakim danom bez nikotina. Za prestanak korištenja Zyna, snusa, nikotinskih vrećica i vapea.",
        "BESPLATNO",
        ["Brojač dana bez nikotina i najduži niz", "Dnevni check-in i kalendar", "Virtualni vrt koji raste s vama", "Način žudnje: vođeno disanje da prebrodite poriv", "Posrtaj ne briše vaš vrt", "Apple Watch i widgeti za početni zaslon", "Privatno na uređaju, bez računa"],
        "BLOOM+ (OPCIONALNO)",
        ["Obrasci vaše žudnje", "Potpuna zdravstvena vremenska crta s izvorima", "Dnevnik s pitanjima", "Postignuća i prekretnice", "Ušteđeni novac i vrećice"],
        "Bloom+ je dostupan kao mjesečna ili godišnja pretplata s automatskim obnavljanjem, obje s besplatnim probnim razdobljem od 1 tjedna za nove pretplatnike koji ispunjavaju uvjete, ili kao jednokratna doživotna kupnja. Cijene su prikazane u aplikaciji prije kupnje i razlikuju se po regiji. Plaćanje se naplaćuje s vašeg Apple ID-ja pri potvrdi. Pretplata se automatski obnavlja ako se ne otkaže najmanje 24 sata prije kraja razdoblja. Upravljajte ili otkažite u postavkama računa za App Store.",
        "Quit Zyn je alat za praćenje vlastitog napretka, a ne liječnički savjet.",
        "Novo: način žudnje. Kad poriv stigne, besplatno pokrenite kratko vođeno disanje.\nPosrtaj više ne briše vaš vrt: brojač kreće ispočetka, stablo zadržava polovicu rasta, a posrtaj unesen greškom može se poništiti.\nBloom+ sada prikazuje obrasce vaše žudnje.\nWidgeti i Apple Watch sada prikazuju isto stablo, uz ostale ispravke.",
    ),
    "hu": (
        "A Quit Zyn napszámlálóval, napi check-innel és minden nikotinmentes nappal növekvő virtuális kerttel segít nikotinmentesen maradni. Zyn, snüssz, nikotintasak és vape elhagyásához.",
        "INGYENES",
        ["Nikotinmentes napszámláló és leghosszabb sorozat", "Napi check-in és naptár", "Veled növekvő virtuális kert", "Sóvárgás mód: vezetett légzés, hogy átvészeld a késztetést", "Egy visszaesés nem törli a kertedet", "Apple Watch és kezdőképernyő-widgetek", "Privát az eszközön, fiók nélkül"],
        "BLOOM+ (OPCIONÁLIS)",
        ["Sóvárgásaid mintázatai", "Teljes egészség-idővonal forrásokkal", "Napló kérdésekkel", "Eredmények és mérföldkövek", "Megspórolt pénz és tasakok"],
        "A Bloom+ havi vagy éves, automatikusan megújuló előfizetésként érhető el, mindkettő 1 hetes ingyenes próbaidőszakkal a jogosult új előfizetők számára, vagy egyszeri, élethosszig tartó vásárlásként. Az árak vásárlás előtt megjelennek az appban, és régiónként eltérnek. A fizetés megerősítéskor az Apple ID-dat terheli. Az előfizetés automatikusan megújul, hacsak nem mondod le legalább 24 órával az időszak vége előtt. Kezelés vagy lemondás az App Store-fiókod beállításaiban.",
        "A Quit Zyn saját előrehaladásod követésére szolgáló eszköz, nem orvosi tanács.",
        "Új: sóvárgás mód. Ha jön a késztetés, indíts ingyen egy rövid vezetett légzést.\nEgy visszaesés már nem törli a kertedet: a számláló újraindul, a fa megtartja növekedése felét, és a tévedésből rögzített visszaesés visszavonható.\nA Bloom+ mostantól mutatja a sóvárgásaid mintázatait.\nA widgetek és az Apple Watch mostantól ugyanazt a fát mutatják, további javításokkal.",
    ),
    "id": (
        "Quit Zyn membantu Anda tetap bebas nikotin dengan penghitung hari, check-in harian, dan taman virtual yang tumbuh setiap hari bebas nikotin. Untuk berhenti Zyn, snus, kantong nikotin, dan vape.",
        "GRATIS",
        ["Penghitung hari bebas nikotin dan rekor terpanjang", "Check-in harian dan kalender", "Taman virtual yang tumbuh bersama Anda", "Mode ngidam: sesi napas terpandu untuk melewati dorongan", "Kambuh tidak menghapus taman Anda", "Apple Watch dan widget layar utama", "Privat di perangkat, tanpa akun"],
        "BLOOM+ (OPSIONAL)",
        ["Pola ngidam Anda", "Linimasa kesehatan lengkap dengan sumber", "Jurnal dengan pertanyaan pemandu", "Pencapaian dan tonggak", "Uang dan kantong yang dihemat"],
        "Bloom+ tersedia sebagai langganan bulanan atau tahunan yang diperpanjang otomatis, keduanya dengan uji coba gratis 1 minggu untuk pelanggan baru yang memenuhi syarat, atau sebagai pembelian seumur hidup sekali bayar. Harga ditampilkan di app sebelum membeli dan berbeda menurut wilayah. Pembayaran ditagihkan ke Apple ID Anda saat konfirmasi. Langganan diperpanjang otomatis kecuali dibatalkan setidaknya 24 jam sebelum periode berakhir. Kelola atau batalkan di pengaturan akun App Store Anda.",
        "Quit Zyn adalah alat untuk memantau kemajuan sendiri, bukan nasihat medis.",
        "Baru: mode ngidam. Saat dorongan datang, mulai sesi napas terpandu singkat secara gratis.\nKambuh tidak lagi menghapus taman Anda: penghitung dimulai ulang, pohon menyimpan setengah pertumbuhannya, dan kambuh yang salah dicatat dapat dibatalkan.\nBloom+ kini menampilkan pola ngidam Anda.\nWidget dan Apple Watch kini sesuai dengan pohon Anda, ditambah perbaikan lain.",
    ),
    "it": (
        "Quit Zyn ti aiuta a restare senza nicotina con un contatore dei giorni, un check-in quotidiano e un giardino virtuale che cresce a ogni giorno senza nicotina. Per smettere con Zyn, snus, bustine di nicotina e svapo.",
        "GRATIS",
        ["Contatore dei giorni senza nicotina e serie più lunga", "Check-in quotidiano e calendario", "Giardino virtuale che cresce con te", "Modalità voglia: una respirazione guidata per lasciar passare l'impulso", "Una ricaduta non cancella il tuo giardino", "Apple Watch e widget per la schermata Home", "Privato sul dispositivo, nessun account"],
        "BLOOM+ (OPZIONALE)",
        ["I tuoi schemi di voglia", "Timeline della salute completa con fonti", "Diario con spunti", "Traguardi e obiettivi", "Denaro e bustine risparmiati"],
        "Bloom+ è disponibile come abbonamento mensile o annuale a rinnovo automatico, entrambi con una prova gratuita di 1 settimana per i nuovi abbonati idonei, oppure come acquisto unico a vita. I prezzi sono mostrati nell'app prima dell'acquisto e variano in base alla regione. Il pagamento viene addebitato sul tuo ID Apple alla conferma. L'abbonamento si rinnova automaticamente se non viene annullato almeno 24 ore prima della fine del periodo. Gestisci o annulla nelle impostazioni del tuo account App Store.",
        "Quit Zyn è uno strumento per monitorare i tuoi progressi, non un consiglio medico.",
        "Novità: modalità voglia. Quando arriva l'impulso, avvia gratis una breve respirazione guidata.\nUna ricaduta non cancella più il tuo giardino: il contatore riparte, l'albero conserva metà della crescita e una ricaduta registrata per errore si può annullare.\nBloom+ ora mostra i tuoi schemi di voglia.\nWidget e Apple Watch ora mostrano lo stesso albero dell'app, oltre ad altre correzioni.",
    ),
    "ja": (
        "Quit Zynは、日数カウンター、毎日のチェックイン、ニコチンフリーの日ごとに育つバーチャルガーデンで、ニコチンのない毎日を支えます。Zyn、スヌース、ニコチンパウチ、電子タバコをやめたい方に。",
        "無料",
        ["ニコチンフリーの日数カウンターと最長記録", "毎日のチェックインとカレンダー", "一緒に育つバーチャルガーデン", "欲求モード：衝動をやり過ごすガイド付き呼吸セッション", "スリップしてもガーデンは消えません", "Apple Watchとホーム画面ウィジェット", "データは端末内に保存、アカウント不要"],
        "BLOOM+（オプション）",
        ["あなたの欲求のパターン", "出典付きの完全な健康タイムライン", "問いかけ付きの日記", "実績とマイルストーン", "節約できたお金とパウチ"],
        "Bloom+は、月額または年額の自動更新サブスクリプション（対象となる新規登録者はどちらも1週間の無料トライアル付き）、または買い切りのライフタイム購入でご利用いただけます。価格は購入前にアプリ内で表示され、地域によって異なります。お支払いは購入確認時にApple IDに請求されます。サブスクリプションは、期間終了の24時間前までに解約しない限り自動更新されます。管理や解約はApp Storeのアカウント設定から行えます。",
        "Quit Zynは自分の進捗を記録するためのツールであり、医療上のアドバイスではありません。",
        "新機能：欲求モード。衝動を感じたら、短いガイド付き呼吸セッションを無料で始められます。\nスリップしてもガーデンは消えなくなりました。カウンターはリセットされますが、木は成長の半分を保ち、誤って記録したスリップは取り消せます。\nBloom+で欲求のパターンを確認できるようになりました。\nウィジェットとApple Watchの木がアプリと一致するようになったほか、不具合を修正しました。",
    ),
    "kn-IN": (
        "Quit Zyn ದಿನಗಳ ಎಣಿಕೆ, ದೈನಂದಿನ ಚೆಕ್-ಇನ್ ಮತ್ತು ಪ್ರತಿ ನಿಕೋಟಿನ್ ಮುಕ್ತ ದಿನ ಬೆಳೆಯುವ ವರ್ಚುವಲ್ ತೋಟದೊಂದಿಗೆ ನಿಮಗೆ ನಿಕೋಟಿನ್ ಮುಕ್ತವಾಗಿರಲು ಸಹಾಯ ಮಾಡುತ್ತದೆ. Zyn, ಸ್ನಸ್, ನಿಕೋಟಿನ್ ಪೌಚ್ ಮತ್ತು ವೇಪಿಂಗ್ ಬಿಡಲು.",
        "ಉಚಿತ",
        ["ನಿಕೋಟಿನ್ ಮುಕ್ತ ದಿನಗಳ ಎಣಿಕೆ ಮತ್ತು ಅತಿ ದೀರ್ಘ ಸರಣಿ", "ದೈನಂದಿನ ಚೆಕ್-ಇನ್ ಮತ್ತು ಕ್ಯಾಲೆಂಡರ್", "ನಿಮ್ಮೊಂದಿಗೆ ಬೆಳೆಯುವ ವರ್ಚುವಲ್ ತೋಟ", "ಕ್ರೇವಿಂಗ್ ಮೋಡ್: ಬಯಕೆಯನ್ನು ದಾಟಲು ಮಾರ್ಗದರ್ಶಿತ ಉಸಿರಾಟ ಅವಧಿ", "ಒಂದು ಸ್ಲಿಪ್ ನಿಮ್ಮ ತೋಟವನ್ನು ಅಳಿಸುವುದಿಲ್ಲ", "Apple Watch ಮತ್ತು ಹೋಮ್ ಸ್ಕ್ರೀನ್ ವಿಜೆಟ್‌ಗಳು", "ಸಾಧನದಲ್ಲಿ ಖಾಸಗಿ, ಖಾತೆ ಬೇಕಿಲ್ಲ"],
        "BLOOM+ (ಐಚ್ಛಿಕ)",
        ["ನಿಮ್ಮ ಕ್ರೇವಿಂಗ್ ಮಾದರಿಗಳು", "ಮೂಲಗಳೊಂದಿಗೆ ಸಂಪೂರ್ಣ ಆರೋಗ್ಯ ಟೈಮ್‌ಲೈನ್", "ಪ್ರಾಂಪ್ಟ್‌ಗಳೊಂದಿಗೆ ದಿನಚರಿ", "ಸಾಧನೆಗಳು ಮತ್ತು ಮೈಲಿಗಲ್ಲುಗಳು", "ಉಳಿಸಿದ ಹಣ ಮತ್ತು ಪೌಚ್‌ಗಳು"],
        "Bloom+ ಮಾಸಿಕ ಅಥವಾ ವಾರ್ಷಿಕ ಸ್ವಯಂ-ನವೀಕರಣ ಚಂದಾದಾರಿಕೆಯಾಗಿ ಲಭ್ಯವಿದೆ, ಎರಡಕ್ಕೂ ಅರ್ಹ ಹೊಸ ಚಂದಾದಾರರಿಗೆ 1 ವಾರದ ಉಚಿತ ಪ್ರಯೋಗ, ಅಥವಾ ಒಂದು ಬಾರಿಯ ಜೀವಮಾನ ಖರೀದಿಯಾಗಿ. ಖರೀದಿಸುವ ಮೊದಲು ಆ್ಯಪ್‌ನಲ್ಲಿ ಬೆಲೆಗಳನ್ನು ತೋರಿಸಲಾಗುತ್ತದೆ ಮತ್ತು ಪ್ರದೇಶಕ್ಕೆ ಅನುಗುಣವಾಗಿ ಬದಲಾಗುತ್ತವೆ. ದೃಢೀಕರಣದ ಸಮಯದಲ್ಲಿ ನಿಮ್ಮ Apple ID ಗೆ ಶುಲ್ಕ ವಿಧಿಸಲಾಗುತ್ತದೆ. ಅವಧಿ ಮುಗಿಯುವ ಕನಿಷ್ಠ 24 ಗಂಟೆಗಳ ಮೊದಲು ರದ್ದುಗೊಳಿಸದಿದ್ದರೆ ಚಂದಾದಾರಿಕೆ ಸ್ವಯಂಚಾಲಿತವಾಗಿ ನವೀಕರಣಗೊಳ್ಳುತ್ತದೆ. App Store ಖಾತೆ ಸೆಟ್ಟಿಂಗ್‌ಗಳಲ್ಲಿ ನಿರ್ವಹಿಸಿ ಅಥವಾ ರದ್ದುಗೊಳಿಸಿ.",
        "Quit Zyn ಸ್ವಂತ ಪ್ರಗತಿಯನ್ನು ಗಮನಿಸುವ ಸಾಧನ, ವೈದ್ಯಕೀಯ ಸಲಹೆ ಅಲ್ಲ.",
        "ಹೊಸದು: ಕ್ರೇವಿಂಗ್ ಮೋಡ್. ಬಯಕೆ ಬಂದಾಗ ಉಚಿತವಾಗಿ ಚಿಕ್ಕ ಮಾರ್ಗದರ್ಶಿತ ಉಸಿರಾಟ ಅವಧಿಯನ್ನು ಪ್ರಾರಂಭಿಸಿ.\nಸ್ಲಿಪ್ ಇನ್ನು ನಿಮ್ಮ ತೋಟವನ್ನು ಅಳಿಸುವುದಿಲ್ಲ: ಕೌಂಟರ್ ಮತ್ತೆ ಆರಂಭವಾಗುತ್ತದೆ, ಮರ ತನ್ನ ಅರ್ಧ ಬೆಳವಣಿಗೆಯನ್ನು ಉಳಿಸಿಕೊಳ್ಳುತ್ತದೆ, ಮತ್ತು ತಪ್ಪಾಗಿ ದಾಖಲಿಸಿದ ಸ್ಲಿಪ್ ಅನ್ನು ರದ್ದುಗೊಳಿಸಬಹುದು.\nBloom+ ಈಗ ನಿಮ್ಮ ಕ್ರೇವಿಂಗ್ ಮಾದರಿಗಳನ್ನು ತೋರಿಸುತ್ತದೆ.\nವಿಜೆಟ್‌ಗಳು ಮತ್ತು Apple Watch ಈಗ ನಿಮ್ಮ ಮರಕ್ಕೆ ಹೊಂದಿಕೆಯಾಗುತ್ತವೆ, ಜೊತೆಗೆ ಇತರ ಸರಿಪಡಿಕೆಗಳು.",
    ),
    "ko": (
        "Quit Zyn은 일수 카운터, 매일 체크인, 니코틴 없는 날마다 자라는 가상 정원으로 니코틴 없는 생활을 이어가도록 돕습니다. Zyn, 스누스, 니코틴 파우치, 전자담배를 끊으려는 분께.",
        "무료",
        ["니코틴 없는 일수 카운터와 최장 기록", "매일 체크인과 캘린더", "함께 자라는 가상 정원", "갈망 모드: 충동을 넘기는 가이드 호흡 세션", "실수해도 정원은 사라지지 않음", "Apple Watch와 홈 화면 위젯", "기기에만 저장, 계정 불필요"],
        "BLOOM+ (선택)",
        ["나의 갈망 패턴", "출처가 포함된 전체 건강 타임라인", "질문이 있는 일기", "업적과 마일스톤", "아낀 돈과 파우치"],
        "Bloom+는 월간 또는 연간 자동 갱신 구독(자격을 갖춘 신규 구독자는 모두 1주 무료 체험 포함) 또는 1회 평생 구매로 이용할 수 있습니다. 가격은 구매 전에 앱에 표시되며 지역에 따라 다릅니다. 결제는 구매 확인 시 Apple ID로 청구됩니다. 구독은 기간 종료 최소 24시간 전에 취소하지 않으면 자동으로 갱신됩니다. App Store 계정 설정에서 관리하거나 취소할 수 있습니다.",
        "Quit Zyn은 스스로 진행 상황을 기록하는 도구이며 의학적 조언이 아닙니다.",
        "새로운 기능: 갈망 모드. 충동이 올 때 짧은 가이드 호흡 세션을 무료로 시작하세요.\n실수해도 이제 정원이 사라지지 않습니다. 카운터는 다시 시작되지만 나무는 성장의 절반을 유지하고, 잘못 기록한 실수는 되돌릴 수 있습니다.\nBloom+에서 이제 갈망 패턴을 볼 수 있습니다.\n위젯과 Apple Watch가 이제 앱의 나무와 일치하며, 기타 문제도 수정했습니다.",
    ),
    "ml-IN": (
        "Quit Zyn ദിവസ എണ്ണം, ദൈനംദിന ചെക്ക്-ഇൻ, ഓരോ നിക്കോട്ടിൻ രഹിത ദിവസവും വളരുന്ന വെർച്വൽ തോട്ടം എന്നിവയിലൂടെ നിക്കോട്ടിൻ രഹിതമായി തുടരാൻ സഹായിക്കുന്നു. Zyn, സ്നസ്, നിക്കോട്ടിൻ പൗച്ചുകൾ, വേപ്പിംഗ് എന്നിവ നിർത്താൻ.",
        "സൗജന്യം",
        ["നിക്കോട്ടിൻ രഹിത ദിവസ എണ്ണവും ഏറ്റവും നീണ്ട തുടർച്ചയും", "ദൈനംദിന ചെക്ക്-ഇന്നും കലണ്ടറും", "നിങ്ങളോടൊപ്പം വളരുന്ന വെർച്വൽ തോട്ടം", "ക്രേവിംഗ് മോഡ്: ആഗ്രഹം കടന്നുപോകാൻ ഗൈഡഡ് ശ്വസന സെഷൻ", "ഒരു വഴുതൽ നിങ്ങളുടെ തോട്ടം മായ്ക്കില്ല", "Apple Watch, ഹോം സ്ക്രീൻ വിജറ്റുകൾ", "ഉപകരണത്തിൽ സ്വകാര്യം, അക്കൗണ്ട് വേണ്ട"],
        "BLOOM+ (ഓപ്ഷണൽ)",
        ["നിങ്ങളുടെ ക്രേവിംഗ് പാറ്റേണുകൾ", "ഉറവിടങ്ങളോടുകൂടിയ പൂർണ്ണ ആരോഗ്യ ടൈംലൈൻ", "ചോദ്യങ്ങളുള്ള ഡയറി", "നേട്ടങ്ങളും നാഴികക്കല്ലുകളും", "ലാഭിച്ച പണവും പൗച്ചുകളും"],
        "Bloom+ പ്രതിമാസ അല്ലെങ്കിൽ വാർഷിക സ്വയം പുതുക്കുന്ന സബ്സ്ക്രിപ്ഷനായി ലഭ്യമാണ്, രണ്ടിലും യോഗ്യരായ പുതിയ സബ്സ്ക്രൈബർമാർക്ക് 1 ആഴ്ച സൗജന്യ ട്രയൽ, അല്ലെങ്കിൽ ഒറ്റത്തവണ ലൈഫ്‌ടൈം വാങ്ങലായി. വാങ്ങുന്നതിന് മുമ്പ് ആപ്പിൽ വിലകൾ കാണിക്കും, പ്രദേശമനുസരിച്ച് വ്യത്യാസപ്പെടും. സ്ഥിരീകരിക്കുമ്പോൾ നിങ്ങളുടെ Apple ID-ൽ നിന്ന് പണം ഈടാക്കും. കാലാവധി അവസാനിക്കുന്നതിന് കുറഞ്ഞത് 24 മണിക്കൂർ മുമ്പ് റദ്ദാക്കിയില്ലെങ്കിൽ സബ്സ്ക്രിപ്ഷൻ സ്വയം പുതുക്കും. App Store അക്കൗണ്ട് ക്രമീകരണങ്ങളിൽ നിയന്ത്രിക്കുകയോ റദ്ദാക്കുകയോ ചെയ്യാം.",
        "Quit Zyn സ്വന്തം പുരോഗതി രേഖപ്പെടുത്താനുള്ള ഉപകരണമാണ്, വൈദ്യോപദേശമല്ല.",
        "പുതിയത്: ക്രേവിംഗ് മോഡ്. ആഗ്രഹം വരുമ്പോൾ ഒരു ചെറിയ ഗൈഡഡ് ശ്വസന സെഷൻ സൗജന്യമായി തുടങ്ങാം.\nഒരു വഴുതൽ ഇനി നിങ്ങളുടെ തോട്ടം മായ്ക്കില്ല: കൗണ്ടർ വീണ്ടും തുടങ്ങും, മരം പകുതി വളർച്ച നിലനിർത്തും, തെറ്റായി രേഖപ്പെടുത്തിയ വഴുതൽ പിൻവലിക്കാം.\nBloom+ ഇപ്പോൾ നിങ്ങളുടെ ക്രേവിംഗ് പാറ്റേണുകൾ കാണിക്കുന്നു.\nവിജറ്റുകളും Apple Watch-ഉം ഇപ്പോൾ നിങ്ങളുടെ മരവുമായി പൊരുത്തപ്പെടുന്നു, കൂടാതെ മറ്റ് പരിഹാരങ്ങളും.",
    ),
    "mr-IN": (
        "Quit Zyn दिवसांची मोजणी, दैनंदिन चेक-इन आणि प्रत्येक निकोटीन-मुक्त दिवशी वाढणारी आभासी बाग यांच्या मदतीने तुम्हाला निकोटीन-मुक्त राहण्यास मदत करते. Zyn, स्नस, निकोटीन पाउच आणि व्हेपिंग सोडण्यासाठी.",
        "मोफत",
        ["निकोटीन-मुक्त दिवसांची मोजणी आणि सर्वात मोठी मालिका", "दैनंदिन चेक-इन आणि कॅलेंडर", "तुमच्यासोबत वाढणारी आभासी बाग", "क्रेव्हिंग मोड: इच्छा ओसरू देण्यासाठी मार्गदर्शित श्वसन सत्र", "एक चूक तुमची बाग पुसत नाही", "Apple Watch आणि होम स्क्रीन विजेट", "डिव्हाइसवर खाजगी, खात्याची गरज नाही"],
        "BLOOM+ (पर्यायी)",
        ["तुमच्या क्रेव्हिंगचे नमुने", "स्रोतांसह संपूर्ण आरोग्य टाइमलाइन", "प्रश्नांसह डायरी", "यश आणि टप्पे", "वाचवलेले पैसे आणि पाउच"],
        "Bloom+ मासिक किंवा वार्षिक स्वयं-नूतनीकरण सदस्यता म्हणून उपलब्ध आहे, दोन्हीमध्ये पात्र नवीन सदस्यांसाठी 1 आठवड्याची मोफत चाचणी, किंवा एकदाच करायची आजीवन खरेदी म्हणून. खरेदीपूर्वी ॲपमध्ये किमती दाखवल्या जातात आणि प्रदेशानुसार बदलतात. पुष्टी करताना तुमच्या Apple ID वरून पैसे आकारले जातात. कालावधी संपण्याच्या किमान 24 तास आधी रद्द न केल्यास सदस्यता आपोआप नूतनीकृत होते. App Store खाते सेटिंग्जमध्ये व्यवस्थापित करा किंवा रद्द करा.",
        "Quit Zyn हे स्वतःची प्रगती नोंदवण्याचे साधन आहे, वैद्यकीय सल्ला नाही.",
        "नवीन: क्रेव्हिंग मोड. इच्छा झाली की मोफत एक छोटे मार्गदर्शित श्वसन सत्र सुरू करा.\nचूक आता तुमची बाग पुसत नाही: काउंटर पुन्हा सुरू होतो, झाड आपली अर्धी वाढ राखते, आणि चुकून नोंदवलेली चूक मागे घेता येते.\nBloom+ आता तुमच्या क्रेव्हिंगचे नमुने दाखवते.\nविजेट आणि Apple Watch आता तुमच्या झाडाशी जुळतात, सोबत इतर दुरुस्त्या.",
    ),
    "ms": (
        "Quit Zyn membantu anda kekal bebas nikotin dengan pembilang hari, daftar masuk harian dan taman maya yang membesar setiap hari bebas nikotin. Untuk berhenti Zyn, snus, uncang nikotin dan vape.",
        "PERCUMA",
        ["Pembilang hari bebas nikotin dan rekod terpanjang", "Daftar masuk harian dan kalendar", "Taman maya yang membesar bersama anda", "Mod keinginan: sesi pernafasan berpandu untuk melepasi dorongan", "Tergelincir tidak memadam taman anda", "Apple Watch dan widget skrin utama", "Peribadi pada peranti, tiada akaun"],
        "BLOOM+ (PILIHAN)",
        ["Corak keinginan anda", "Garis masa kesihatan penuh dengan sumber", "Diari dengan soalan panduan", "Pencapaian dan detik penting", "Wang dan uncang yang dijimatkan"],
        "Bloom+ tersedia sebagai langganan bulanan atau tahunan yang diperbaharui secara automatik, kedua-duanya dengan percubaan percuma 1 minggu untuk pelanggan baharu yang layak, atau sebagai pembelian seumur hidup sekali bayar. Harga dipaparkan dalam app sebelum membeli dan berbeza mengikut rantau. Bayaran dicaj ke Apple ID anda semasa pengesahan. Langganan diperbaharui secara automatik melainkan dibatalkan sekurang-kurangnya 24 jam sebelum tempoh tamat. Urus atau batalkan dalam tetapan akaun App Store anda.",
        "Quit Zyn ialah alat untuk menjejak kemajuan sendiri, bukan nasihat perubatan.",
        "Baharu: mod keinginan. Apabila dorongan datang, mulakan sesi pernafasan berpandu yang singkat secara percuma.\nTergelincir tidak lagi memadam taman anda: pembilang bermula semula, pokok mengekalkan separuh pertumbuhannya, dan catatan tergelincir yang tersilap boleh dibatalkan.\nBloom+ kini menunjukkan corak keinginan anda.\nWidget dan Apple Watch kini sepadan dengan pokok anda, serta pembaikan lain.",
    ),
    "nl-NL": (
        "Quit Zyn helpt je nicotinevrij te blijven met een dagteller, een dagelijkse check-in en een virtuele tuin die groeit met elke nicotinevrije dag. Om te stoppen met Zyn, snus, nicotinezakjes en vapen.",
        "GRATIS",
        ["Teller voor nicotinevrije dagen en langste reeks", "Dagelijkse check-in en kalender", "Virtuele tuin die met je meegroeit", "Trekmodus: een begeleide ademoefening om de trek te laten zakken", "Een terugval wist je tuin niet", "Apple Watch en widgets voor het beginscherm", "Privé op je apparaat, geen account"],
        "BLOOM+ (OPTIONEEL)",
        ["Jouw trekpatronen", "Volledige gezondheidstijdlijn met bronnen", "Dagboek met vragen", "Prestaties en mijlpalen", "Bespaard geld en zakjes"],
        "Bloom+ is beschikbaar als maandelijks of jaarlijks automatisch verlengd abonnement, beide met een gratis proefperiode van 1 week voor nieuwe abonnees die in aanmerking komen, of als eenmalige aankoop voor altijd. Prijzen worden vóór aankoop in de app getoond en verschillen per regio. De betaling wordt bij bevestiging via je Apple ID in rekening gebracht. Het abonnement wordt automatisch verlengd tenzij je het minstens 24 uur voor het einde van de periode opzegt. Beheer of annuleer het in de instellingen van je App Store-account.",
        "Quit Zyn is een hulpmiddel om je eigen voortgang bij te houden, geen medisch advies.",
        "Nieuw: trekmodus. Als de trek opkomt, start je gratis een korte begeleide ademoefening.\nEen terugval wist je tuin niet meer: de teller begint opnieuw, je boom houdt de helft van zijn groei en een per ongeluk ingevoerde terugval kun je ongedaan maken.\nBloom+ toont nu je trekpatronen.\nWidgets en Apple Watch tonen nu dezelfde boom als de app, plus andere verbeteringen.",
    ),
    "no": (
        "Quit Zyn hjelper deg å holde deg nikotinfri med dagteller, daglig innsjekk og en virtuell hage som vokser for hver nikotinfri dag. For deg som slutter med Zyn, snus, nikotinposer og vape.",
        "GRATIS",
        ["Nikotinfri dagteller og lengste rekke", "Daglig innsjekk og kalender", "Virtuell hage som vokser med deg", "Suggmodus: en veiledet pusteøvelse for å komme gjennom suget", "Et tilbakefall sletter ikke hagen din", "Apple Watch og widgeter for Hjem-skjermen", "Privat på enheten, ingen konto"],
        "BLOOM+ (VALGFRITT)",
        ["Dine suggmønstre", "Full helsetidslinje med kilder", "Dagbok med spørsmål", "Prestasjoner og milepæler", "Sparte penger og poser"],
        "Bloom+ fås som månedlig eller årlig abonnement som fornyes automatisk, begge med 1 ukes gratis prøveperiode for kvalifiserte nye abonnenter, eller som et engangskjøp for livstid. Prisene vises i appen før du kjøper og varierer etter region. Betalingen belastes Apple-ID-en din ved bekreftelse. Abonnementet fornyes automatisk med mindre det sies opp minst 24 timer før perioden utløper. Administrer eller si opp i innstillingene for App Store-kontoen din.",
        "Quit Zyn er et verktøy for å følge din egen fremgang, ikke medisinske råd.",
        "Nytt: suggmodus. Når suget kommer, kan du starte en kort veiledet pusteøvelse gratis.\nEt tilbakefall sletter ikke lenger hagen din: telleren starter på nytt, treet beholder halvparten av veksten, og et tilbakefall registrert ved en feil kan angres.\nBloom+ viser nå suggmønstrene dine.\nWidgeter og Apple Watch viser nå samme tre som appen, pluss andre rettelser.",
    ),
    "or-IN": (
        "Quit Zyn ଦିନ ଗଣନା, ଦୈନିକ ଚେକ-ଇନ୍ ଏବଂ ପ୍ରତ୍ୟେକ ନିକୋଟିନ-ମୁକ୍ତ ଦିନରେ ବଢୁଥିବା ଭର୍ଚୁଆଲ୍ ବଗିଚା ସହିତ ଆପଣଙ୍କୁ ନିକୋଟିନ-ମୁକ୍ତ ରହିବାରେ ସାହାଯ୍ୟ କରେ। Zyn, ସ୍ନସ୍, ନିକୋଟିନ ପାଉଚ୍ ଏବଂ ଭେପିଂ ଛାଡିବା ପାଇଁ।",
        "ମାଗଣା",
        ["ନିକୋଟିନ-ମୁକ୍ତ ଦିନ ଗଣନା ଏବଂ ସବୁଠାରୁ ଲମ୍ବା ଧାରା", "ଦୈନିକ ଚେକ-ଇନ୍ ଏବଂ କ୍ୟାଲେଣ୍ଡର", "ଆପଣଙ୍କ ସହ ବଢୁଥିବା ଭର୍ଚୁଆଲ୍ ବଗିଚା", "କ୍ରେଭିଂ ମୋଡ୍: ଇଚ୍ଛା ପାର କରିବା ପାଇଁ ମାର୍ଗଦର୍ଶିତ ଶ୍ୱାସ ଅଧିବେଶନ", "ଗୋଟିଏ ସ୍ଲିପ୍ ଆପଣଙ୍କ ବଗିଚା ଲିଭାଏ ନାହିଁ", "Apple Watch ଏବଂ ହୋମ ସ୍କ୍ରିନ ୱିଜେଟ୍", "ଉପକରଣରେ ବ୍ୟକ୍ତିଗତ, ଖାତା ଆବଶ୍ୟକ ନାହିଁ"],
        "BLOOM+ (ବିକଳ୍ପ)",
        ["ଆପଣଙ୍କ କ୍ରେଭିଂର ଢାଞ୍ଚା", "ଉତ୍ସ ସହିତ ସମ୍ପୂର୍ଣ୍ଣ ସ୍ୱାସ୍ଥ୍ୟ ଟାଇମଲାଇନ୍", "ପ୍ରଶ୍ନ ସହିତ ଡାଇରି", "ସଫଳତା ଏବଂ ମାଇଲଖୁଣ୍ଟ", "ସଞ୍ଚୟ କରିଥିବା ଟଙ୍କା ଏବଂ ପାଉଚ୍"],
        "Bloom+ ମାସିକ କିମ୍ବା ବାର୍ଷିକ ସ୍ୱୟଂ-ନବୀକରଣ ସଦସ୍ୟତା ଭାବେ ଉପଲବ୍ଧ, ଦୁଇଟିରେ ଯୋଗ୍ୟ ନୂଆ ସଦସ୍ୟଙ୍କ ପାଇଁ 1 ସପ୍ତାହର ମାଗଣା ଟ୍ରାଏଲ୍, କିମ୍ବା ଥରେ କରାଯାଉଥିବା ଆଜୀବନ କ୍ରୟ ଭାବେ। କିଣିବା ପୂର୍ବରୁ ଆପରେ ମୂଲ୍ୟ ଦେଖାଯାଏ ଏବଂ ଅଞ୍ଚଳ ଅନୁସାରେ ଭିନ୍ନ ହୁଏ। ନିଶ୍ଚିତ କରିବା ସମୟରେ ଆପଣଙ୍କ Apple ID ରୁ ଦେୟ ନିଆଯାଏ। ଅବଧି ଶେଷ ହେବାର ଅତି କମରେ 24 ଘଣ୍ଟା ପୂର୍ବରୁ ବାତିଲ ନକଲେ ସଦସ୍ୟତା ସ୍ୱୟଂଚାଳିତ ଭାବେ ନବୀକରଣ ହୁଏ। App Store ଖାତା ସେଟିଂସରେ ପରିଚାଳନା କିମ୍ବା ବାତିଲ କରନ୍ତୁ।",
        "Quit Zyn ନିଜ ପ୍ରଗତି ଟ୍ରାକ୍ କରିବାର ଏକ ସାଧନ, ଚିକିତ୍ସା ପରାମର୍ଶ ନୁହେଁ।",
        "ନୂଆ: କ୍ରେଭିଂ ମୋଡ୍। ଇଚ୍ଛା ଆସିଲେ ମାଗଣାରେ ଏକ ଛୋଟ ମାର୍ଗଦର୍ଶିତ ଶ୍ୱାସ ଅଧିବେଶନ ଆରମ୍ଭ କରନ୍ତୁ।\nସ୍ଲିପ୍ ଆଉ ଆପଣଙ୍କ ବଗିଚା ଲିଭାଏ ନାହିଁ: କାଉଣ୍ଟର ପୁଣି ଆରମ୍ଭ ହୁଏ, ଗଛ ନିଜର ଅଧା ବୃଦ୍ଧି ରଖେ, ଏବଂ ଭୁଲରେ ଲଗ୍ ହୋଇଥିବା ସ୍ଲିପ୍ ଫେରାଇ ହେବ।\nBloom+ ବର୍ତ୍ତମାନ ଆପଣଙ୍କ କ୍ରେଭିଂର ଢାଞ୍ଚା ଦେଖାଏ।\nୱିଜେଟ୍ ଏବଂ Apple Watch ବର୍ତ୍ତମାନ ଆପଣଙ୍କ ଗଛ ସହ ମେଳ ଖାଏ, ସହିତ ଅନ୍ୟ ସଂଶୋଧନ।",
    ),
    "pa-IN": (
        "Quit Zyn ਦਿਨਾਂ ਦੀ ਗਿਣਤੀ, ਰੋਜ਼ਾਨਾ ਚੈੱਕ-ਇਨ ਅਤੇ ਹਰ ਨਿਕੋਟੀਨ-ਮੁਕਤ ਦਿਨ ਨਾਲ ਵਧਦੇ ਵਰਚੁਅਲ ਬਾਗ ਰਾਹੀਂ ਤੁਹਾਨੂੰ ਨਿਕੋਟੀਨ-ਮੁਕਤ ਰਹਿਣ ਵਿੱਚ ਮਦਦ ਕਰਦਾ ਹੈ। Zyn, ਸਨੱਸ, ਨਿਕੋਟੀਨ ਪਾਊਚ ਅਤੇ ਵੇਪਿੰਗ ਛੱਡਣ ਲਈ।",
        "ਮੁਫ਼ਤ",
        ["ਨਿਕੋਟੀਨ-ਮੁਕਤ ਦਿਨਾਂ ਦੀ ਗਿਣਤੀ ਅਤੇ ਸਭ ਤੋਂ ਲੰਮੀ ਲੜੀ", "ਰੋਜ਼ਾਨਾ ਚੈੱਕ-ਇਨ ਅਤੇ ਕੈਲੰਡਰ", "ਤੁਹਾਡੇ ਨਾਲ ਵਧਦਾ ਵਰਚੁਅਲ ਬਾਗ", "ਕ੍ਰੇਵਿੰਗ ਮੋਡ: ਇੱਛਾ ਲੰਘਾਉਣ ਲਈ ਗਾਈਡਡ ਸਾਹ ਸੈਸ਼ਨ", "ਇੱਕ ਸਲਿੱਪ ਤੁਹਾਡਾ ਬਾਗ ਨਹੀਂ ਮਿਟਾਉਂਦੀ", "Apple Watch ਅਤੇ ਹੋਮ ਸਕ੍ਰੀਨ ਵਿਜੇਟ", "ਡਿਵਾਈਸ 'ਤੇ ਨਿੱਜੀ, ਖਾਤੇ ਦੀ ਲੋੜ ਨਹੀਂ"],
        "BLOOM+ (ਵਿਕਲਪਿਕ)",
        ["ਤੁਹਾਡੀ ਕ੍ਰੇਵਿੰਗ ਦੇ ਪੈਟਰਨ", "ਸਰੋਤਾਂ ਸਮੇਤ ਪੂਰੀ ਸਿਹਤ ਟਾਈਮਲਾਈਨ", "ਸਵਾਲਾਂ ਵਾਲੀ ਡਾਇਰੀ", "ਪ੍ਰਾਪਤੀਆਂ ਅਤੇ ਮੀਲ ਪੱਥਰ", "ਬਚਾਏ ਪੈਸੇ ਅਤੇ ਪਾਊਚ"],
        "Bloom+ ਮਾਸਿਕ ਜਾਂ ਸਾਲਾਨਾ ਆਪਣੇ-ਆਪ ਨਵਿਆਉਣ ਵਾਲੀ ਸਬਸਕ੍ਰਿਪਸ਼ਨ ਵਜੋਂ ਉਪਲਬਧ ਹੈ, ਦੋਵਾਂ ਵਿੱਚ ਯੋਗ ਨਵੇਂ ਸਬਸਕ੍ਰਾਈਬਰਾਂ ਲਈ 1 ਹਫ਼ਤੇ ਦਾ ਮੁਫ਼ਤ ਟ੍ਰਾਇਲ, ਜਾਂ ਇੱਕ ਵਾਰ ਦੀ ਲਾਈਫ਼ਟਾਈਮ ਖਰੀਦ ਵਜੋਂ। ਖਰੀਦਣ ਤੋਂ ਪਹਿਲਾਂ ਐਪ ਵਿੱਚ ਕੀਮਤਾਂ ਦਿਖਾਈਆਂ ਜਾਂਦੀਆਂ ਹਨ ਅਤੇ ਖੇਤਰ ਮੁਤਾਬਕ ਵੱਖਰੀਆਂ ਹੁੰਦੀਆਂ ਹਨ। ਪੁਸ਼ਟੀ ਵੇਲੇ ਤੁਹਾਡੀ Apple ID ਤੋਂ ਭੁਗਤਾਨ ਲਿਆ ਜਾਂਦਾ ਹੈ। ਮਿਆਦ ਖਤਮ ਹੋਣ ਤੋਂ ਘੱਟੋ-ਘੱਟ 24 ਘੰਟੇ ਪਹਿਲਾਂ ਰੱਦ ਨਾ ਕਰਨ 'ਤੇ ਸਬਸਕ੍ਰਿਪਸ਼ਨ ਆਪਣੇ-ਆਪ ਨਵਿਆਈ ਜਾਂਦੀ ਹੈ। App Store ਖਾਤਾ ਸੈਟਿੰਗਾਂ ਵਿੱਚ ਪ੍ਰਬੰਧ ਕਰੋ ਜਾਂ ਰੱਦ ਕਰੋ।",
        "Quit Zyn ਆਪਣੀ ਤਰੱਕੀ ਟ੍ਰੈਕ ਕਰਨ ਦਾ ਟੂਲ ਹੈ, ਡਾਕਟਰੀ ਸਲਾਹ ਨਹੀਂ।",
        "ਨਵਾਂ: ਕ੍ਰੇਵਿੰਗ ਮੋਡ। ਇੱਛਾ ਆਉਣ 'ਤੇ ਮੁਫ਼ਤ ਵਿੱਚ ਇੱਕ ਛੋਟਾ ਗਾਈਡਡ ਸਾਹ ਸੈਸ਼ਨ ਸ਼ੁਰੂ ਕਰੋ।\nਸਲਿੱਪ ਹੁਣ ਤੁਹਾਡਾ ਬਾਗ ਨਹੀਂ ਮਿਟਾਉਂਦੀ: ਕਾਊਂਟਰ ਦੁਬਾਰਾ ਸ਼ੁਰੂ ਹੁੰਦਾ ਹੈ, ਰੁੱਖ ਆਪਣਾ ਅੱਧਾ ਵਾਧਾ ਰੱਖਦਾ ਹੈ, ਅਤੇ ਗਲਤੀ ਨਾਲ ਦਰਜ ਸਲਿੱਪ ਵਾਪਸ ਲਈ ਜਾ ਸਕਦੀ ਹੈ।\nBloom+ ਹੁਣ ਤੁਹਾਡੀ ਕ੍ਰੇਵਿੰਗ ਦੇ ਪੈਟਰਨ ਦਿਖਾਉਂਦਾ ਹੈ।\nਵਿਜੇਟ ਅਤੇ Apple Watch ਹੁਣ ਤੁਹਾਡੇ ਰੁੱਖ ਨਾਲ ਮੇਲ ਖਾਂਦੇ ਹਨ, ਨਾਲ ਹੋਰ ਸੁਧਾਰ।",
    ),
    "pl": (
        "Quit Zyn pomaga pozostać bez nikotyny dzięki licznikowi dni, codziennemu check-inowi i wirtualnemu ogrodowi, który rośnie z każdym dniem bez nikotyny. Dla rzucających Zyn, snus, saszetki nikotynowe i e-papierosy.",
        "ZA DARMO",
        ["Licznik dni bez nikotyny i najdłuższa seria", "Codzienny check-in i kalendarz", "Wirtualny ogród, który rośnie razem z Tobą", "Tryb głodu nikotynowego: prowadzone oddychanie, by przeczekać chęć", "Potknięcie nie usuwa Twojego ogrodu", "Apple Watch i widżety na ekran początkowy", "Prywatnie na urządzeniu, bez konta"],
        "BLOOM+ (OPCJONALNIE)",
        ["Wzorce Twojego głodu nikotynowego", "Pełna oś czasu zdrowia ze źródłami", "Dziennik z podpowiedziami", "Osiągnięcia i kamienie milowe", "Zaoszczędzone pieniądze i saszetki"],
        "Bloom+ jest dostępny jako miesięczna lub roczna subskrypcja odnawiana automatycznie, obie z 1-tygodniowym bezpłatnym okresem próbnym dla uprawnionych nowych subskrybentów, lub jako jednorazowy zakup dożywotni. Ceny są widoczne w aplikacji przed zakupem i różnią się w zależności od regionu. Płatność jest pobierana z Twojego Apple ID po potwierdzeniu. Subskrypcja odnawia się automatycznie, jeśli nie zostanie anulowana co najmniej 24 godziny przed końcem okresu. Zarządzaj nią lub anuluj w ustawieniach konta App Store.",
        "Quit Zyn to narzędzie do śledzenia własnych postępów, a nie porada medyczna.",
        "Nowość: tryb głodu nikotynowego. Gdy przyjdzie chęć, uruchom za darmo krótkie prowadzone oddychanie.\nPotknięcie nie usuwa już Twojego ogrodu: licznik zaczyna od nowa, drzewo zachowuje połowę wzrostu, a potknięcie wpisane przez pomyłkę można cofnąć.\nBloom+ pokazuje teraz wzorce Twojego głodu nikotynowego.\nWidżety i Apple Watch pokazują teraz to samo drzewo co aplikacja, plus inne poprawki.",
    ),
    "pt-BR": (
        "O Quit Zyn ajuda você a ficar sem nicotina com contador de dias, check-in diário e um jardim virtual que cresce a cada dia sem nicotina. Para largar Zyn, snus, sachês de nicotina e vape.",
        "GRÁTIS",
        ["Contador de dias sem nicotina e maior sequência", "Check-in diário e calendário", "Jardim virtual que cresce com você", "Modo fissura: uma respiração guiada para deixar a vontade passar", "Um deslize não apaga seu jardim", "Apple Watch e widgets da tela de início", "Privado no dispositivo, sem conta"],
        "BLOOM+ (OPCIONAL)",
        ["Seus padrões de fissura", "Linha do tempo de saúde completa com fontes", "Diário com perguntas", "Conquistas e marcos", "Dinheiro e sachês economizados"],
        "O Bloom+ está disponível como assinatura mensal ou anual com renovação automática, ambas com teste grátis de 1 semana para novos assinantes elegíveis, ou como compra única vitalícia. Os preços são exibidos no app antes da compra e variam por região. O pagamento é cobrado no seu ID Apple na confirmação. A assinatura é renovada automaticamente, a menos que seja cancelada pelo menos 24 horas antes do fim do período. Gerencie ou cancele nos ajustes da sua conta da App Store.",
        "O Quit Zyn é uma ferramenta para acompanhar seu próprio progresso, não um conselho médico.",
        "Novo: modo fissura. Quando a vontade bater, comece de graça uma respiração guiada curta.\nUm deslize não apaga mais seu jardim: o contador recomeça, a árvore mantém metade do crescimento e um deslize registrado por engano pode ser desfeito.\nO Bloom+ agora mostra seus padrões de fissura.\nWidgets e Apple Watch agora mostram a mesma árvore do app, além de outras correções.",
    ),
    "pt-PT": (
        "O Quit Zyn ajuda-o a manter-se sem nicotina com um contador de dias, check-in diário e um jardim virtual que cresce a cada dia sem nicotina. Para deixar o Zyn, o snus, as saquetas de nicotina e o vape.",
        "GRÁTIS",
        ["Contador de dias sem nicotina e maior sequência", "Check-in diário e calendário", "Jardim virtual que cresce consigo", "Modo desejo: uma respiração guiada para deixar passar a vontade", "Um deslize não apaga o seu jardim", "Apple Watch e widgets do ecrã principal", "Privado no dispositivo, sem conta"],
        "BLOOM+ (OPCIONAL)",
        ["Os seus padrões de desejo", "Cronologia de saúde completa com fontes", "Diário com perguntas", "Conquistas e marcos", "Dinheiro e saquetas poupados"],
        "O Bloom+ está disponível como subscrição mensal ou anual com renovação automática, ambas com uma avaliação gratuita de 1 semana para novos subscritores elegíveis, ou como compra única vitalícia. Os preços são apresentados na app antes da compra e variam consoante a região. O pagamento é cobrado no seu ID Apple na confirmação. A subscrição renova-se automaticamente, exceto se for cancelada pelo menos 24 horas antes do fim do período. Faça a gestão ou cancele nas definições da sua conta da App Store.",
        "O Quit Zyn é uma ferramenta para acompanhar o seu progresso, não um conselho médico.",
        "Novo: modo desejo. Quando a vontade surgir, inicie gratuitamente uma breve respiração guiada.\nUm deslize já não apaga o seu jardim: o contador recomeça, a árvore mantém metade do crescimento e um deslize registado por engano pode ser anulado.\nO Bloom+ mostra agora os seus padrões de desejo.\nOs widgets e o Apple Watch mostram agora a mesma árvore da app, além de outras correções.",
    ),
    "ro": (
        "Quit Zyn te ajută să rămâi fără nicotină cu un contor de zile, check-in zilnic și o grădină virtuală care crește cu fiecare zi fără nicotină. Pentru renunțarea la Zyn, snus, pliculețe cu nicotină și vape.",
        "GRATUIT",
        ["Contor de zile fără nicotină și cea mai lungă serie", "Check-in zilnic și calendar", "Grădină virtuală care crește odată cu tine", "Modul poftă: o respirație ghidată ca să treacă impulsul", "O recădere nu îți șterge grădina", "Apple Watch și widgeturi pentru ecranul principal", "Privat pe dispozitiv, fără cont"],
        "BLOOM+ (OPȚIONAL)",
        ["Tiparele poftelor tale", "Cronologie completă a sănătății, cu surse", "Jurnal cu întrebări", "Realizări și repere", "Bani și pliculețe economisite"],
        "Bloom+ este disponibil ca abonament lunar sau anual cu reînnoire automată, ambele cu o perioadă de probă gratuită de 1 săptămână pentru abonații noi eligibili, sau ca achiziție unică pe viață. Prețurile sunt afișate în aplicație înainte de cumpărare și variază în funcție de regiune. Plata se debitează din ID-ul Apple la confirmare. Abonamentul se reînnoiește automat dacă nu este anulat cu cel puțin 24 de ore înainte de sfârșitul perioadei. Gestionează sau anulează din setările contului App Store.",
        "Quit Zyn este un instrument pentru urmărirea propriului progres, nu un sfat medical.",
        "Nou: modul poftă. Când vine impulsul, pornește gratuit o respirație ghidată scurtă.\nO recădere nu îți mai șterge grădina: contorul o ia de la capăt, copacul își păstrează jumătate din creștere, iar o recădere înregistrată din greșeală poate fi anulată.\nBloom+ arată acum tiparele poftelor tale.\nWidgeturile și Apple Watch arată acum același copac ca aplicația, plus alte remedieri.",
    ),
    "ru": (
        "Quit Zyn помогает жить без никотина: счётчик дней, ежедневный чек-ин и виртуальный сад, который растёт с каждым днём без никотина. Для тех, кто бросает Zyn, снюс, никотиновые пакетики и вейп.",
        "БЕСПЛАТНО",
        ["Счётчик дней без никотина и самая длинная серия", "Ежедневный чек-ин и календарь", "Виртуальный сад, который растёт вместе с вами", "Режим тяги: дыхательная практика с подсказками, чтобы переждать желание", "Срыв не стирает ваш сад", "Apple Watch и виджеты для экрана «Домой»", "Данные только на устройстве, без аккаунта"],
        "BLOOM+ (ОПЦИОНАЛЬНО)",
        ["Закономерности вашей тяги", "Полная хронология здоровья с источниками", "Дневник с вопросами", "Достижения и вехи", "Сэкономленные деньги и пакетики"],
        "Bloom+ доступен как ежемесячная или ежегодная подписка с автопродлением, обе с бесплатным пробным периодом 1 неделя для подходящих новых подписчиков, или как разовая пожизненная покупка. Цены показываются в приложении до покупки и зависят от региона. Оплата списывается с Apple ID при подтверждении. Подписка продлевается автоматически, если не отменить её минимум за 24 часа до конца периода. Управлять подпиской или отменить её можно в настройках учётной записи App Store.",
        "Quit Zyn является инструментом для отслеживания собственного прогресса, а не медицинской рекомендацией.",
        "Новое: режим тяги. Когда накатывает желание, бесплатно запустите короткую дыхательную практику.\nСрыв больше не стирает ваш сад: счётчик начинается заново, дерево сохраняет половину роста, а ошибочно записанный срыв можно отменить.\nBloom+ теперь показывает закономерности вашей тяги.\nВиджеты и Apple Watch теперь показывают то же дерево, что и приложение, плюс другие исправления.",
    ),
    "sk": (
        "Quit Zyn vám pomôže zostať bez nikotínu vďaka počítadlu dní, dennému check-inu a virtuálnej záhrade, ktorá rastie s každým dňom bez nikotínu. Pre tých, čo prestávajú so Zynom, snusom, nikotínovými vrecúškami a vapovaním.",
        "ZADARMO",
        ["Počítadlo dní bez nikotínu a najdlhšia séria", "Denný check-in a kalendár", "Virtuálna záhrada, ktorá rastie s vami", "Režim chuti: riadené dýchanie na prečkanie nutkania", "Pošmyknutie nevymaže vašu záhradu", "Apple Watch a widgety na plochu", "Súkromne v zariadení, bez účtu"],
        "BLOOM+ (VOLITEĽNÉ)",
        ["Vzorce vašich chutí", "Úplná zdravotná časová os so zdrojmi", "Denník s otázkami", "Úspechy a míľniky", "Ušetrené peniaze a vrecúška"],
        "Bloom+ je k dispozícii ako mesačné alebo ročné automaticky obnovované predplatné, obe s týždennou bezplatnou skúšobnou verziou pre oprávnených nových predplatiteľov, alebo ako jednorazový doživotný nákup. Ceny sa zobrazujú v aplikácii pred nákupom a líšia sa podľa regiónu. Platba sa strhne z vášho Apple ID pri potvrdení. Predplatné sa automaticky obnoví, ak ho nezrušíte aspoň 24 hodín pred koncom obdobia. Spravovať alebo zrušiť ho môžete v nastaveniach účtu App Store.",
        "Quit Zyn je nástroj na sledovanie vlastného pokroku, nie lekárska rada.",
        "Novinka: režim chuti. Keď príde nutkanie, spustite zadarmo krátke riadené dýchanie.\nPošmyknutie už nevymaže vašu záhradu: počítadlo začne odznova, strom si ponechá polovicu rastu a omylom zadané pošmyknutie sa dá vrátiť.\nBloom+ teraz ukazuje vzorce vašich chutí.\nWidgety a Apple Watch teraz zobrazujú rovnaký strom ako aplikácia, plus ďalšie opravy.",
    ),
    "sl-SI": (
        "Quit Zyn vam pomaga ostati brez nikotina s števcem dni, dnevnim check-inom in virtualnim vrtom, ki raste z vsakim dnem brez nikotina. Za opuščanje Zyna, snusa, nikotinskih vrečk in vejpanja.",
        "BREZPLAČNO",
        ["Števec dni brez nikotina in najdaljši niz", "Dnevni check-in in koledar", "Virtualni vrt, ki raste z vami", "Način želje: vodeno dihanje, da preživite nagon", "Spodrsljaj ne izbriše vašega vrta", "Apple Watch in gradniki za začetni zaslon", "Zasebno v napravi, brez računa"],
        "BLOOM+ (IZBIRNO)",
        ["Vzorci vaših želja", "Celotna časovnica zdravja z viri", "Dnevnik z vprašanji", "Dosežki in mejniki", "Prihranjen denar in vrečke"],
        "Bloom+ je na voljo kot mesečna ali letna naročnina s samodejnim podaljšanjem, obe z enotedenskim brezplačnim preizkusom za upravičene nove naročnike, ali kot enkraten dosmrtni nakup. Cene so prikazane v aplikaciji pred nakupom in se razlikujejo glede na regijo. Plačilo se ob potrditvi zaračuna vašemu Apple ID-ju. Naročnina se samodejno podaljša, razen če jo prekličete vsaj 24 ur pred koncem obdobja. Upravljate ali prekličete jo v nastavitvah računa App Store.",
        "Quit Zyn je orodje za spremljanje lastnega napredka, ne zdravniški nasvet.",
        "Novo: način želje. Ko pride nagon, brezplačno zaženite kratko vodeno dihanje.\nSpodrsljaj ne izbriše več vašega vrta: števec začne znova, drevo obdrži polovico rasti, pomotoma vnesen spodrsljaj pa lahko razveljavite.\nBloom+ zdaj prikazuje vzorce vaših želja.\nGradniki in Apple Watch zdaj prikazujejo isto drevo kot aplikacija, poleg drugih popravkov.",
    ),
    "sv": (
        "Quit Zyn hjälper dig att hålla dig nikotinfri med dagräknare, daglig check-in och en virtuell trädgård som växer för varje nikotinfri dag. För dig som slutar med Zyn, snus, vitt snus och vape.",
        "GRATIS",
        ["Nikotinfri dagräknare och längsta svit", "Daglig check-in och kalender", "Virtuell trädgård som växer med dig", "Sugläge: en guidad andningsövning för att rida ut suget", "Ett återfall raderar inte din trädgård", "Apple Watch och widgetar för hemskärmen", "Privat på enheten, inget konto"],
        "BLOOM+ (VALFRITT)",
        ["Dina sugmönster", "Fullständig hälsotidslinje med källor", "Dagbok med frågor", "Prestationer och milstolpar", "Sparade pengar och påsar"],
        "Bloom+ finns som månads- eller årsabonnemang som förnyas automatiskt, båda med 1 veckas gratis provperiod för berättigade nya prenumeranter, eller som ett engångsköp för livstid. Priserna visas i appen innan du köper och varierar mellan regioner. Betalningen debiteras ditt Apple-ID vid bekräftelse. Abonnemanget förnyas automatiskt om det inte sägs upp minst 24 timmar innan perioden slutar. Hantera eller säg upp i inställningarna för ditt App Store-konto.",
        "Quit Zyn är ett verktyg för att följa dina egna framsteg, inte medicinsk rådgivning.",
        "Nytt: sugläge. När suget kommer kan du starta en kort guidad andningsövning gratis.\nEtt återfall raderar inte längre din trädgård: räknaren börjar om, trädet behåller halva sin tillväxt och ett återfall som registrerats av misstag kan ångras.\nBloom+ visar nu dina sugmönster.\nWidgetar och Apple Watch visar nu samma träd som appen, plus andra rättningar.",
    ),
    "ta-IN": (
        "Quit Zyn நாள் எண்ணிக்கை, தினசரி செக்-இன் மற்றும் ஒவ்வொரு நிக்கோட்டின் இல்லாத நாளிலும் வளரும் மெய்நிகர் தோட்டம் மூலம் நிக்கோட்டின் இல்லாமல் இருக்க உதவுகிறது. Zyn, ஸ்னஸ், நிக்கோட்டின் பௌச்கள் மற்றும் வேப்பிங்கை விட.",
        "இலவசம்",
        ["நிக்கோட்டின் இல்லாத நாள் எண்ணிக்கையும் நீண்ட தொடரும்", "தினசரி செக்-இன் மற்றும் நாட்காட்டி", "உங்களுடன் வளரும் மெய்நிகர் தோட்டம்", "ஏக்க பயன்முறை: தூண்டுதலைக் கடக்க வழிகாட்டப்பட்ட சுவாச அமர்வு", "ஒரு சறுக்கல் உங்கள் தோட்டத்தை அழிக்காது", "Apple Watch மற்றும் முகப்புத் திரை விட்ஜெட்கள்", "சாதனத்தில் தனிப்பட்டது, கணக்கு தேவையில்லை"],
        "BLOOM+ (விருப்பம்)",
        ["உங்கள் ஏக்க முறைகள்", "ஆதாரங்களுடன் முழு ஆரோக்கிய காலவரிசை", "கேள்விகளுடன் நாட்குறிப்பு", "சாதனைகள் மற்றும் மைல்கற்கள்", "சேமித்த பணம் மற்றும் பௌச்கள்"],
        "Bloom+ மாதாந்திர அல்லது ஆண்டு தானாகப் புதுப்பிக்கும் சந்தாவாகக் கிடைக்கிறது, இரண்டிலும் தகுதியுள்ள புதிய சந்தாதாரர்களுக்கு 1 வார இலவச சோதனை, அல்லது ஒருமுறை வாழ்நாள் வாங்குதலாக. வாங்கும் முன் விலைகள் ஆப்பில் காட்டப்படும், பகுதிக்கு ஏற்ப மாறுபடும். உறுதிப்படுத்தும்போது உங்கள் Apple ID-இல் கட்டணம் வசூலிக்கப்படும். காலம் முடிவதற்கு குறைந்தது 24 மணிநேரம் முன் ரத்து செய்யாவிட்டால் சந்தா தானாகப் புதுப்பிக்கப்படும். App Store கணக்கு அமைப்புகளில் நிர்வகிக்கவும் அல்லது ரத்து செய்யவும்.",
        "Quit Zyn என்பது உங்கள் முன்னேற்றத்தைக் கண்காணிக்கும் கருவி, மருத்துவ ஆலோசனை அல்ல.",
        "புதியது: ஏக்க பயன்முறை. தூண்டுதல் வரும்போது இலவசமாக ஒரு குறுகிய வழிகாட்டப்பட்ட சுவாச அமர்வைத் தொடங்குங்கள்.\nசறுக்கல் இனி உங்கள் தோட்டத்தை அழிக்காது: கவுண்டர் மீண்டும் தொடங்கும், மரம் அதன் பாதி வளர்ச்சியை வைத்திருக்கும், தவறாகப் பதிவுசெய்த சறுக்கலைத் திரும்பப் பெறலாம்.\nBloom+ இப்போது உங்கள் ஏக்க முறைகளைக் காட்டுகிறது.\nவிட்ஜெட்களும் Apple Watch-உம் இப்போது உங்கள் மரத்துடன் பொருந்துகின்றன, மேலும் பிற திருத்தங்கள்.",
    ),
    "te-IN": (
        "Quit Zyn రోజుల లెక్క, రోజువారీ చెక్-ఇన్ మరియు ప్రతి నికోటిన్ రహిత రోజుతో పెరిగే వర్చువల్ తోటతో మీరు నికోటిన్ రహితంగా ఉండటానికి సహాయపడుతుంది. Zyn, స్నస్, నికోటిన్ పౌచ్‌లు మరియు వేపింగ్ మానేయడానికి.",
        "ఉచితం",
        ["నికోటిన్ రహిత రోజుల లెక్క మరియు పొడవైన వరుస", "రోజువారీ చెక్-ఇన్ మరియు క్యాలెండర్", "మీతో పాటు పెరిగే వర్చువల్ తోట", "క్రేవింగ్ మోడ్: కోరికను దాటడానికి మార్గదర్శక శ్వాస సెషన్", "ఒక స్లిప్ మీ తోటను చెరిపివేయదు", "Apple Watch మరియు హోమ్ స్క్రీన్ విడ్జెట్‌లు", "పరికరంలో ప్రైవేట్, ఖాతా అవసరం లేదు"],
        "BLOOM+ (ఐచ్ఛికం)",
        ["మీ క్రేవింగ్ నమూనాలు", "మూలాలతో పూర్తి ఆరోగ్య టైమ్‌లైన్", "ప్రశ్నలతో డైరీ", "విజయాలు మరియు మైలురాళ్లు", "ఆదా చేసిన డబ్బు మరియు పౌచ్‌లు"],
        "Bloom+ నెలవారీ లేదా వార్షిక స్వయంచాలక పునరుద్ధరణ సబ్‌స్క్రిప్షన్‌గా అందుబాటులో ఉంది, రెండింటిలోనూ అర్హత గల కొత్త సబ్‌స్క్రైబర్‌లకు 1 వారం ఉచిత ట్రయల్, లేదా ఒకసారి జీవితకాల కొనుగోలుగా. కొనుగోలుకు ముందు యాప్‌లో ధరలు చూపబడతాయి మరియు ప్రాంతాన్ని బట్టి మారుతాయి. నిర్ధారణ సమయంలో మీ Apple IDకి చెల్లింపు వసూలు చేయబడుతుంది. వ్యవధి ముగియడానికి కనీసం 24 గంటల ముందు రద్దు చేయకపోతే సబ్‌స్క్రిప్షన్ స్వయంచాలకంగా పునరుద్ధరించబడుతుంది. App Store ఖాతా సెట్టింగ్‌లలో నిర్వహించండి లేదా రద్దు చేయండి.",
        "Quit Zyn మీ పురోగతిని ట్రాక్ చేసే సాధనం, వైద్య సలహా కాదు.",
        "కొత్తది: క్రేవింగ్ మోడ్. కోరిక వచ్చినప్పుడు ఉచితంగా చిన్న మార్గదర్శక శ్వాస సెషన్ ప్రారంభించండి.\nస్లిప్ ఇకపై మీ తోటను చెరిపివేయదు: కౌంటర్ మళ్లీ మొదలవుతుంది, చెట్టు తన సగం పెరుగుదలను ఉంచుకుంటుంది, పొరపాటున నమోదు చేసిన స్లిప్‌ను రద్దు చేయవచ్చు.\nBloom+ ఇప్పుడు మీ క్రేవింగ్ నమూనాలను చూపుతుంది.\nవిడ్జెట్‌లు మరియు Apple Watch ఇప్పుడు మీ చెట్టుతో సరిపోలుతాయి, ఇంకా ఇతర పరిష్కారాలు.",
    ),
    "th": (
        "Quit Zyn ช่วยให้คุณปลอดนิโคตินด้วยตัวนับวัน การเช็คอินรายวัน และสวนเสมือนที่เติบโตทุกวันที่ปลอดนิโคติน สำหรับคนที่เลิก Zyn, สนุส, ซองนิโคติน และบุหรี่ไฟฟ้า",
        "ฟรี",
        ["ตัวนับวันปลอดนิโคตินและสถิติต่อเนื่องสูงสุด", "เช็คอินรายวันและปฏิทิน", "สวนเสมือนที่เติบโตไปกับคุณ", "โหมดอยาก: การหายใจแบบมีคำแนะนำเพื่อผ่านช่วงที่อยาก", "การพลาดไม่ได้ลบสวนของคุณ", "Apple Watch และวิดเจ็ตหน้าจอโฮม", "ข้อมูลอยู่บนอุปกรณ์ ไม่ต้องมีบัญชี"],
        "BLOOM+ (ทางเลือก)",
        ["รูปแบบความอยากของคุณ", "ไทม์ไลน์สุขภาพฉบับเต็มพร้อมแหล่งอ้างอิง", "บันทึกประจำวันพร้อมคำถามชวนคิด", "ความสำเร็จและหมุดหมาย", "เงินและซองที่ประหยัดได้"],
        "Bloom+ มีให้เลือกเป็นการสมัครสมาชิกรายเดือนหรือรายปีที่ต่ออายุอัตโนมัติ ทั้งสองแบบมีช่วงทดลองใช้ฟรี 1 สัปดาห์สำหรับสมาชิกใหม่ที่มีสิทธิ์ หรือเป็นการซื้อตลอดชีพแบบครั้งเดียว ราคาจะแสดงในแอปก่อนซื้อและแตกต่างกันตามภูมิภาค ระบบจะเรียกเก็บเงินจาก Apple ID ของคุณเมื่อยืนยัน การสมัครสมาชิกจะต่ออายุอัตโนมัติ เว้นแต่จะยกเลิกอย่างน้อย 24 ชั่วโมงก่อนสิ้นสุดรอบ จัดการหรือยกเลิกได้ในการตั้งค่าบัญชี App Store",
        "Quit Zyn เป็นเครื่องมือติดตามความก้าวหน้าของตนเอง ไม่ใช่คำแนะนำทางการแพทย์",
        "ใหม่: โหมดอยาก เมื่อความอยากมาถึง เริ่มการหายใจแบบมีคำแนะนำสั้นๆ ได้ฟรี\nการพลาดจะไม่ลบสวนของคุณอีกต่อไป ตัวนับจะเริ่มใหม่ ต้นไม้คงการเติบโตไว้ครึ่งหนึ่ง และยกเลิกการพลาดที่บันทึกผิดได้\nBloom+ แสดงรูปแบบความอยากของคุณแล้ว\nวิดเจ็ตและ Apple Watch แสดงต้นไม้ตรงกับแอปแล้ว พร้อมการแก้ไขอื่นๆ",
    ),
    "tr": (
        "Quit Zyn; gün sayacı, günlük check-in ve nikotinsiz her günle büyüyen sanal bir bahçeyle nikotinsiz kalmanıza yardımcı olur. Zyn, snus, nikotin poşetleri ve vape bırakanlar için.",
        "ÜCRETSİZ",
        ["Nikotinsiz gün sayacı ve en uzun seri", "Günlük check-in ve takvim", "Sizinle büyüyen sanal bahçe", "İstek modu: dürtüyü atlatmak için rehberli nefes egzersizi", "Bir kayma bahçenizi silmez", "Apple Watch ve ana ekran widget'ları", "Cihazda gizli, hesap gerekmez"],
        "BLOOM+ (İSTEĞE BAĞLI)",
        ["İstek örüntüleriniz", "Kaynaklarıyla eksiksiz sağlık zaman çizelgesi", "Sorulu günlük", "Başarılar ve kilometre taşları", "Tasarruf edilen para ve poşetler"],
        "Bloom+, otomatik yenilenen aylık veya yıllık abonelik olarak (ikisinde de uygun yeni aboneler için 1 haftalık ücretsiz deneme) ya da tek seferlik ömür boyu satın alma olarak sunulur. Fiyatlar satın almadan önce uygulamada gösterilir ve bölgeye göre değişir. Ödeme, onay sırasında Apple kimliğinizden alınır. Abonelik, dönem bitiminden en az 24 saat önce iptal edilmezse otomatik olarak yenilenir. App Store hesap ayarlarınızdan yönetebilir veya iptal edebilirsiniz.",
        "Quit Zyn kendi ilerlemenizi takip etmeye yarayan bir araçtır, tıbbi tavsiye değildir.",
        "Yeni: istek modu. Dürtü geldiğinde kısa bir rehberli nefes egzersizini ücretsiz başlatın.\nBir kayma artık bahçenizi silmiyor: sayaç yeniden başlar, ağaç büyümesinin yarısını korur ve yanlışlıkla girilen bir kayma geri alınabilir.\nBloom+ artık istek örüntülerinizi gösteriyor.\nWidget'lar ve Apple Watch artık uygulamadaki ağaçla aynı, ayrıca başka düzeltmeler.",
    ),
    "uk": (
        "Quit Zyn допомагає жити без нікотину: лічильник днів, щоденний чек-ін і віртуальний сад, що росте з кожним днем без нікотину. Для тих, хто кидає Zyn, снюс, нікотинові пакетики та вейп.",
        "БЕЗКОШТОВНО",
        ["Лічильник днів без нікотину і найдовша серія", "Щоденний чек-ін і календар", "Віртуальний сад, що росте разом з вами", "Режим тяги: дихальна вправа з підказками, щоб перечекати бажання", "Зрив не стирає ваш сад", "Apple Watch і віджети для початкового екрана", "Дані лише на пристрої, без облікового запису"],
        "BLOOM+ (ЗА БАЖАННЯМ)",
        ["Закономірності вашої тяги", "Повна хронологія здоров'я з джерелами", "Щоденник із запитаннями", "Досягнення та віхи", "Зекономлені гроші й пакетики"],
        "Bloom+ доступний як щомісячна або щорічна підписка з автоматичним поновленням, обидві з безкоштовним пробним періодом 1 тиждень для відповідних нових передплатників, або як одноразова довічна покупка. Ціни показуються в застосунку перед покупкою і залежать від регіону. Оплата стягується з вашого Apple ID під час підтвердження. Підписка поновлюється автоматично, якщо її не скасувати щонайменше за 24 години до кінця періоду. Керувати підпискою або скасувати її можна в налаштуваннях облікового запису App Store.",
        "Quit Zyn є інструментом для відстеження власного прогресу, а не медичною порадою.",
        "Нове: режим тяги. Коли накочує бажання, безкоштовно запустіть коротку дихальну вправу з підказками.\nЗрив більше не стирає ваш сад: лічильник починається знову, дерево зберігає половину росту, а помилково записаний зрив можна скасувати.\nBloom+ тепер показує закономірності вашої тяги.\nВіджети й Apple Watch тепер показують те саме дерево, що й застосунок, а також інші виправлення.",
    ),
    "ur-PK": (
        "Quit Zyn دنوں کی گنتی، روزانہ چیک اِن اور ہر نکوٹین سے پاک دن کے ساتھ بڑھنے والے ورچوئل باغ سے آپ کو نکوٹین سے پاک رہنے میں مدد دیتا ہے۔ Zyn، سنس، نکوٹین پاؤچ اور ویپنگ چھوڑنے کے لیے۔",
        "مفت",
        ["نکوٹین سے پاک دنوں کی گنتی اور سب سے لمبا سلسلہ", "روزانہ چیک اِن اور کیلنڈر", "آپ کے ساتھ بڑھنے والا ورچوئل باغ", "کریونگ موڈ: خواہش گزارنے کے لیے رہنمائی والا سانس کا سیشن", "ایک لغزش آپ کا باغ نہیں مٹاتی", "Apple Watch اور ہوم اسکرین ویجیٹ", "ڈیوائس پر نجی، اکاؤنٹ کی ضرورت نہیں"],
        "BLOOM+ (اختیاری)",
        ["آپ کی خواہش کے پیٹرن", "ذرائع کے ساتھ مکمل صحت ٹائم لائن", "سوالات والی ڈائری", "کامیابیاں اور سنگ میل", "بچائے گئے پیسے اور پاؤچ"],
        "Bloom+ ماہانہ یا سالانہ خودکار تجدید والی سبسکرپشن کے طور پر دستیاب ہے، دونوں میں اہل نئے سبسکرائبرز کے لیے 1 ہفتے کا مفت ٹرائل، یا ایک بار کی تاحیات خریداری کے طور پر۔ قیمتیں خریدنے سے پہلے ایپ میں دکھائی جاتی ہیں اور علاقے کے لحاظ سے مختلف ہوتی ہیں۔ تصدیق پر آپ کے Apple ID سے ادائیگی لی جاتی ہے۔ مدت ختم ہونے سے کم از کم 24 گھنٹے پہلے منسوخ نہ کرنے پر سبسکرپشن خودکار طور پر تجدید ہو جاتی ہے۔ App Store اکاؤنٹ کی ترتیبات میں انتظام یا منسوخ کریں۔",
        "Quit Zyn اپنی پیش رفت ٹریک کرنے کا ٹول ہے، طبی مشورہ نہیں۔",
        "نیا: کریونگ موڈ۔ خواہش آنے پر مفت میں رہنمائی والا ایک مختصر سانس کا سیشن شروع کریں۔\nلغزش اب آپ کا باغ نہیں مٹاتی: کاؤنٹر دوبارہ شروع ہوتا ہے، درخت اپنی آدھی نشوونما رکھتا ہے، اور غلطی سے درج لغزش واپس لی جا سکتی ہے۔\nBloom+ اب آپ کی خواہش کے پیٹرن دکھاتا ہے۔\nویجیٹ اور Apple Watch اب آپ کے درخت سے میل کھاتے ہیں، ساتھ میں دیگر اصلاحات۔",
    ),
    "vi": (
        "Quit Zyn giúp bạn sống không nicotin với bộ đếm ngày, check-in hằng ngày và khu vườn ảo lớn lên theo mỗi ngày không nicotin. Dành cho người bỏ Zyn, snus, túi nicotin và thuốc lá điện tử.",
        "MIỄN PHÍ",
        ["Bộ đếm ngày không nicotin và chuỗi dài nhất", "Check-in hằng ngày và lịch", "Khu vườn ảo lớn lên cùng bạn", "Chế độ thèm: bài thở có hướng dẫn để vượt qua cơn thèm", "Một lần lỡ không xóa khu vườn của bạn", "Apple Watch và widget màn hình chính", "Riêng tư trên thiết bị, không cần tài khoản"],
        "BLOOM+ (TÙY CHỌN)",
        ["Quy luật cơn thèm của bạn", "Dòng thời gian sức khỏe đầy đủ kèm nguồn", "Nhật ký có câu hỏi gợi ý", "Thành tích và cột mốc", "Tiền và túi nicotin đã tiết kiệm"],
        "Bloom+ có dạng gói đăng ký hằng tháng hoặc hằng năm tự động gia hạn, cả hai đều có 1 tuần dùng thử miễn phí cho người đăng ký mới đủ điều kiện, hoặc dạng mua trọn đời một lần. Giá được hiển thị trong ứng dụng trước khi mua và khác nhau theo khu vực. Khoản thanh toán được tính vào Apple ID của bạn khi xác nhận. Gói đăng ký tự động gia hạn trừ khi được hủy ít nhất 24 giờ trước khi kết thúc kỳ. Quản lý hoặc hủy trong phần cài đặt tài khoản App Store.",
        "Quit Zyn là công cụ theo dõi tiến trình cá nhân, không phải lời khuyên y tế.",
        "Mới: chế độ thèm. Khi cơn thèm đến, hãy bắt đầu miễn phí một bài thở ngắn có hướng dẫn.\nMột lần lỡ không còn xóa khu vườn: bộ đếm bắt đầu lại, cây giữ một nửa sự phát triển, và lần lỡ ghi nhầm có thể hoàn tác.\nBloom+ giờ hiển thị quy luật cơn thèm của bạn.\nWidget và Apple Watch giờ khớp với cây trong ứng dụng, cùng các bản sửa lỗi khác.",
    ),
    "zh-Hans": (
        "Quit Zyn 通过天数计数器、每日签到，以及随每个无尼古丁日成长的虚拟花园，陪你保持无尼古丁。适合戒 Zyn、口含烟、尼古丁袋和电子烟的你。",
        "免费",
        ["无尼古丁天数计数与最长连续记录", "每日签到与日历", "与你一起成长的虚拟花园", "渴求模式：引导式呼吸练习，陪你度过冲动", "偶尔失守也不会清空你的花园", "Apple Watch 与主屏幕小组件", "数据仅存于设备，无需账户"],
        "BLOOM+（可选）",
        ["你的渴求规律", "附来源的完整健康时间线", "带提示的日记", "成就与里程碑", "节省的金钱和尼古丁袋"],
        "Bloom+ 提供按月或按年自动续订的订阅（符合条件的新订阅者均可享受 1 周免费试用），也可一次性购买终身版。价格会在购买前于 App 内显示，并因地区而异。确认购买时将通过你的 Apple 账户扣款。除非在当期结束前至少 24 小时取消，否则订阅将自动续订。可在 App Store 账户设置中管理或取消。",
        "Quit Zyn 是记录个人进展的工具，并非医疗建议。",
        "新功能：渴求模式。冲动来袭时，免费开始一段简短的引导式呼吸练习。\n偶尔失守不再清空花园：计数器重新开始，树保留一半成长，误记的失守还可以撤销。\nBloom+ 现在会显示你的渴求规律。\n小组件和 Apple Watch 现在与 App 中的树保持一致，并修复了其他问题。",
    ),
    "zh-Hant": (
        "Quit Zyn 透過天數計數器、每日簽到，以及隨每個無尼古丁日成長的虛擬花園，陪你保持無尼古丁。適合戒 Zyn、口含菸、尼古丁袋和電子菸的你。",
        "免費",
        ["無尼古丁天數計數與最長連續紀錄", "每日簽到與日曆", "與你一起成長的虛擬花園", "渴望模式：引導式呼吸練習，陪你度過衝動", "偶爾失守也不會清空你的花園", "Apple Watch 與主畫面小工具", "資料僅存於裝置，無需帳號"],
        "BLOOM+（可選）",
        ["你的渴望規律", "附來源的完整健康時間軸", "附提示的日記", "成就與里程碑", "省下的金錢與尼古丁袋"],
        "Bloom+ 提供按月或按年自動續訂的訂閱（符合資格的新訂閱者皆可享 1 週免費試用），也可一次購買終身版。價格會在購買前於 App 內顯示，並依地區而異。確認購買時將向你的 Apple 帳號收費。除非在當期結束前至少 24 小時取消，否則訂閱將自動續訂。可在 App Store 帳號設定中管理或取消。",
        "Quit Zyn 是記錄個人進展的工具，並非醫療建議。",
        "新功能：渴望模式。衝動來襲時，免費開始一段簡短的引導式呼吸練習。\n偶爾失守不再清空花園：計數器重新開始，樹保留一半成長，誤記的失守也能復原。\nBloom+ 現在會顯示你的渴望規律。\n小工具和 Apple Watch 現在與 App 中的樹一致，並修正了其他問題。",
    ),
}

# Variants that differ only in a few words from their sibling locale.
T["es-MX"] = tuple(
    (s.replace("Gestiona o cancela", "Administra o cancela") if isinstance(s, str) else s)
    for s in T["es-ES"]
)
T["fr-CA"] = tuple(
    (s.replace("et la vape.", "et le vapotage.") if isinstance(s, str) else s)
    for s in T["fr-FR"]
)

KEYWORD_FIXES = {
    # "ayıklık" is sobriety, inherited from the alcohol app.
    "tr": ("ayıklık", "nikotinsiz"),
}

BANNED = re.compile(
    r"střízliv|νηφάλ|פיכח|trijez|triježn|minum|triezv|trezn|ดื่ม|ayık|alkol|тверез|трезв|uống|મદમુક્ત|"
    r"sobr|nüchtern|nykter|ædru|józan|trzeź|清醒|酒|절주|마른 날|干燥|乾いた|alcoh|alcool|drink| ,  |—"
)


def legal_lines(description: str) -> list[str]:
    return [line for line in description.splitlines() if "http" in line]


def build_localized(locale: str, current: str) -> str:
    intro, free_h, free, plus_h, plus, subs, disc, _ = T[locale]
    assert len(free) == 7 and len(plus) == 5, locale
    legal = legal_lines(current)
    assert any("stdeula" in l for l in legal) and any("privacy" in l for l in legal), locale
    parts = [
        intro,
        free_h + "\n" + "\n".join("• " + b for b in free),
        plus_h + "\n" + "\n".join("• " + b for b in plus),
        subs,
        disc,
        "\n".join(legal),
    ]
    return "\n\n".join(parts)


def build_english(current: str) -> str:
    out = current.replace(
        "- Apple Watch companion to check in and see your streak.",
        "- Apple Watch companion that shows your streak.",
    )
    # Idempotent: rerunning against copy this script already wrote has to be a
    # no-op, or the only way to re-verify the result is to restore the backup.
    anchor = "ON YOUR HOME SCREEN & APPLE WATCH (FREE)"
    assert anchor in out
    if "WHEN A CRAVING HITS" not in out:
        out = out.replace(anchor, EN_CRAVING_SECTION + anchor, 1)
    plus_anchor = "A small upgrade unlocks the full experience:\n"
    patterns_line = "- Your craving patterns: when urges hit, what sets them off, and how long yours last\n"
    assert plus_anchor in out
    if patterns_line not in out:
        out = out.replace(plus_anchor, plus_anchor + patterns_line, 1)
    sub_anchor = "Subscription Details"
    assert sub_anchor in out
    if EN_DISCLAIMER.strip() not in out:
        out = out.replace(sub_anchor, EN_DISCLAIMER + sub_anchor, 1)
    return out


def main() -> int:
    apply = "--apply" in sys.argv
    c = L.ASCClient(L.bearer_token(*L.load_credentials()))
    app = L.find_app(c, BUNDLE)
    ver = L.find_version_by_string(c, app["id"], VERSION)
    if not ver or ver["attributes"]["appStoreState"] != "PREPARE_FOR_SUBMISSION":
        print(f"ERROR: {VERSION} is not an editable draft")
        return 1
    locs = L.list_all(c, f"/appStoreVersions/{ver['id']}/appStoreVersionLocalizations?limit=200")

    plan: dict[str, dict] = {}
    errors: list[str] = []
    for loc in locs:
        a = loc["attributes"]
        code = a["locale"]
        current = a.get("description") or ""
        if code.startswith("en-"):
            desc, wn = build_english(current), EN_WHATS_NEW
        elif code in T:
            desc, wn = build_localized(code, current), T[code][7]
        else:
            errors.append(f"{code}: no template")
            continue
        attrs = {"description": desc, "whatsNew": wn}
        if code in KEYWORD_FIXES:
            old, new = KEYWORD_FIXES[code]
            kw = a.get("keywords") or ""
            if old in kw:
                attrs["keywords"] = kw.replace(old, new)
        for field, value in attrs.items():
            if BANNED.search(value):
                errors.append(f"{code}.{field}: banned term {BANNED.search(value).group(0)!r}")
        if len(desc) > 4000 or len(wn) > 4000:
            errors.append(f"{code}: too long")
        if "keywords" in attrs and len(attrs["keywords"]) > 100:
            errors.append(f"{code}: keywords {len(attrs['keywords'])} > 100")
        if "stdeula" not in desc:
            errors.append(f"{code}: missing EULA link")
        plan[code] = {"id": loc["id"], "before": a, "attrs": attrs}
        print(f"{code:8} desc {len(current):4} -> {len(desc):4}  whatsNew {len(wn):3}"
              + (f"  keywords {len(attrs['keywords'])}" if "keywords" in attrs else ""))

    if errors:
        print("\n".join(errors))
        return 1
    print(f"{len(plan)} locales validated")
    if not apply:
        return 0

    backup = ROOT / "fastlane" / f"asc-{VERSION}-localizations-before.json"
    backup.write_text(json.dumps({k: v["before"] for k, v in plan.items()}, ensure_ascii=False, indent=1))
    for code, p in sorted(plan.items()):
        c.patch(
            f"/appStoreVersionLocalizations/{p['id']}",
            {"data": {"type": "appStoreVersionLocalizations", "id": p["id"], "attributes": p["attrs"]}},
        )
        d = META / code
        if d.is_dir():
            (d / "description.txt").write_text(p["attrs"]["description"] + "\n", encoding="utf-8")
            (d / "release_notes.txt").write_text(p["attrs"]["whatsNew"] + "\n", encoding="utf-8")
            if "keywords" in p["attrs"]:
                (d / "keywords.txt").write_text(p["attrs"]["keywords"] + "\n", encoding="utf-8")
        print(f"  patched {code}")
    print(f"backup: {backup.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
