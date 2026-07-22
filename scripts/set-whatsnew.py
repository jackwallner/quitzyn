#!/usr/bin/env python3
"""Populate native 'What's New' (whatsNew) for every ASC 1.1.1 version localization.

Metadata/polish release — notes are short and honest. Writes fastlane release_notes.txt
too, then PATCHes whatsNew on each appStoreVersionLocalization (required for an update).
"""
from __future__ import annotations

import os
from pathlib import Path

import asc_lib as L

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "fastlane/metadata"
VERSION = os.environ.get("ASC_APP_VERSION", "1.1.1")

EN = "Behind-the-scenes improvements and fixes to keep Quit Zyn running smoothly. Thank you for being here."

NOTES: dict[str, str] = {
    "en-US": EN, "en-GB": EN, "en-AU": EN, "en-CA": EN,
    "de-DE": "Verbesserungen und Fehlerbehebungen im Hintergrund, damit Quit Zyn reibungslos läuft. Danke, dass du dabei bist.",
    "fr-FR": "Améliorations en coulisses et corrections de bugs pour que Quit Zyn reste fluide. Merci d'être là.",
    "fr-CA": "Améliorations en coulisses et corrections de bugs pour que Quit Zyn reste fluide. Merci d'être là.",
    "es-ES": "Mejoras internas y correcciones de errores para que Quit Zyn funcione mejor. Gracias por estar aquí.",
    "es-MX": "Mejoras internas y correcciones de errores para que Quit Zyn funcione mejor. Gracias por estar aquí.",
    "it": "Miglioramenti dietro le quinte e correzioni di bug per far funzionare Quit Zyn senza intoppi. Grazie di esserci.",
    "pt-BR": "Melhorias nos bastidores e correções de erros para o Quit Zyn funcionar melhor. Obrigado por estar aqui.",
    "pt-PT": "Melhorias nos bastidores e correções de erros para o Quit Zyn funcionar melhor. Obrigado por estar aqui.",
    "nl-NL": "Verbeteringen achter de schermen en bugfixes zodat Quit Zyn soepel werkt. Bedankt dat je er bent.",
    "sv": "Förbättringar bakom kulisserna och buggfixar så att Quit Zyn fungerar smidigt. Tack för att du är här.",
    "no": "Forbedringer bak kulissene og feilrettinger så Quit Zyn fungerer problemfritt. Takk for at du er her.",
    "da": "Forbedringer bag kulisserne og fejlrettelser, så Quit Zyn kører glat. Tak fordi du er her.",
    "fi": "Taustaparannuksia ja virhekorjauksia, jotta Quit Zyn toimii sujuvasti. Kiitos, että olet mukana.",
    "pl": "Ulepszenia w tle i poprawki błędów, aby Quit Zyn działał płynnie. Dziękujemy, że jesteś.",
    "cs": "Vylepšení na pozadí a opravy chyb, aby Quit Zyn běžel hladce. Děkujeme, že jste tu.",
    "sk": "Vylepšenia na pozadí a opravy chýb, aby Quit Zyn fungoval hladko. Ďakujeme, že ste tu.",
    "ru": "Улучшения и исправления, чтобы Quit Zyn работал стабильнее. Спасибо, что вы с нами.",
    "uk": "Покращення та виправлення, щоб Quit Zyn працював стабільніше. Дякуємо, що ви з нами.",
    "ro": "Îmbunătățiri și remedieri pentru ca Quit Zyn să funcționeze mai bine. Mulțumim că ești aici.",
    "hr": "Poboljšanja u pozadini i ispravci grešaka kako bi Quit Zyn radio glatko. Hvala što ste tu.",
    "hu": "Háttérbeli fejlesztések és hibajavítások, hogy a Quit Zyn gördülékenyen működjön. Köszönjük, hogy itt vagy.",
    "sl-SI": "Izboljšave v ozadju in popravki napak, da Quit Zyn deluje gladko. Hvala, da ste z nami.",
    "el": "Βελτιώσεις και διορθώσεις σφαλμάτων για να λειτουργεί ομαλά το Quit Zyn. Ευχαριστούμε που είστε εδώ.",
    "tr": "Quit Zyn'ın sorunsuz çalışması için arka planda iyileştirmeler ve hata düzeltmeleri. Burada olduğun için teşekkürler.",
    "ca": "Millores internes i correccions d'errors perquè Quit Zyn funcioni bé. Gràcies per ser aquí.",
    "id": "Peningkatan di balik layar dan perbaikan bug agar Quit Zyn berjalan lancar. Terima kasih telah hadir.",
    "ms": "Penambahbaikan di sebalik tabir dan pembaikan pepijat supaya Quit Zyn berjalan lancar. Terima kasih kerana berada di sini.",
    "vi": "Cải tiến phía sau và sửa lỗi để Quit Zyn chạy mượt mà. Cảm ơn bạn đã đồng hành.",
    "th": "ปรับปรุงเบื้องหลังและแก้ไขข้อบกพร่องเพื่อให้ Quit Zyn ทำงานได้ราบรื่น ขอบคุณที่อยู่กับเรา",
    "ja": "Quit Zyn をより快適にご利用いただくための改善とバグ修正を行いました。いつもありがとうございます。",
    "ko": "Quit Zyn을 원활하게 사용할 수 있도록 내부 개선과 버그를 수정했습니다. 함께해 주셔서 감사합니다.",
    "zh-Hans": "进行了后台优化和错误修复，让 Quit Zyn 运行更顺畅。感谢一路有你。",
    "zh-Hant": "進行了背景優化與錯誤修復，讓 Quit Zyn 運行更順暢。感謝一路有你。",
    "ar-SA": "تحسينات في الخلفية وإصلاحات للأخطاء ليعمل Quit Zyn بسلاسة. شكرًا لوجودك معنا.",
    "he": "שיפורים מאחורי הקלעים ותיקוני באגים כדי ש-Quit Zyn יפעל חלק. תודה שאתם כאן.",
    "hi": "Quit Zyn को बेहतर चलाने के लिए पर्दे के पीछे सुधार और बग फिक्स। यहाँ होने के लिए धन्यवाद।",
    "bn-BD": "Quit Zyn মসৃণভাবে চালাতে নেপথ্যে উন্নতি ও বাগ সংশোধন। সঙ্গে থাকার জন্য ধন্যবাদ।",
    "gu-IN": "Quit Zyn સરળતાથી ચાલે તે માટે પાછળના સુધારા અને બગ ફિક્સ. અહીં હોવા બદલ આભાર.",
    "kn-IN": "Quit Zyn ಸುಗಮವಾಗಿ ಚಲಿಸಲು ಹಿನ್ನೆಲೆ ಸುಧಾರಣೆಗಳು ಮತ್ತು ದೋಷ ಪರಿಹಾರಗಳು. ಇಲ್ಲಿರುವುದಕ್ಕೆ ಧನ್ಯವಾದಗಳು.",
    "ml-IN": "Quit Zyn സുഗമമായി പ്രവർത്തിക്കാൻ പശ്ചാത്തല മെച്ചപ്പെടുത്തലുകളും ബഗ് പരിഹാരങ്ങളും. കൂടെയുള്ളതിന് നന്ദി.",
    "mr-IN": "Quit Zyn सुरळीत चालण्यासाठी पडद्यामागील सुधारणा आणि बग दुरुस्ती. इथे असल्याबद्दल धन्यवाद.",
    "or-IN": "Quit Zyn ସୁଗମ ଭାବେ ଚାଲିବା ପାଇଁ ପୃଷ୍ଠଭୂମି ଉନ୍ନତି ଓ ତ୍ରୁଟି ସମାଧାନ। ସାଥିରେ ରହିଥିବାରୁ ଧନ୍ୟବାଦ।",
    "pa-IN": "Quit Zyn ਨੂੰ ਸੁਚਾਰੂ ਚਲਾਉਣ ਲਈ ਪਿਛੋਕੜ ਸੁਧਾਰ ਅਤੇ ਬੱਗ ਫਿਕਸ। ਇੱਥੇ ਹੋਣ ਲਈ ਧੰਨਵਾਦ।",
    "ta-IN": "Quit Zyn சீராக இயங்க பின்னணி மேம்பாடுகள் மற்றும் பிழை திருத்தங்கள். உடனிருந்ததற்கு நன்றி.",
    "te-IN": "Quit Zyn సాఫీగా పనిచేయడానికి తెర వెనుక మెరుగుదలలు మరియు బగ్ పరిష్కారాలు. మీతో ఉన్నందుకు ధన్యవాదాలు.",
    "ur-PK": "Quit Zyn کو بہتر چلانے کے لیے پس پردہ بہتری اور بگ فکسز۔ یہاں ہونے کا شکریہ۔",
}


def main() -> int:
    # write repo files
    for loc, note in NOTES.items():
        d = META / loc
        if d.is_dir():
            (d / "release_notes.txt").write_text(note + "\n", encoding="utf-8")
    # PATCH ASC
    kid, iss, kp = L.load_credentials()
    c = L.ASCClient(L.bearer_token(kid, iss, kp))
    app = L.find_app(c, L.bundle_id_from_appfile())
    ver = L.find_version_by_string(c, app["id"], VERSION)
    if not ver:
        print(f"ERROR: version {VERSION} not found")
        return 1
    locs = L.list_all(
        c,
        f"/appStoreVersions/{ver['id']}/appStoreVersionLocalizations"
        f"?fields[appStoreVersionLocalizations]=locale,whatsNew&limit=200",
    )
    by_locale = {l["attributes"]["locale"]: l["id"] for l in locs}
    ok = miss = 0
    for loc, lid in sorted(by_locale.items()):
        note = NOTES.get(loc) or NOTES.get(loc.split("-")[0]) or EN
        c.patch(
            f"/appStoreVersionLocalizations/{lid}",
            {"data": {"type": "appStoreVersionLocalizations", "id": lid, "attributes": {"whatsNew": note}}},
        )
        ok += 1
        if loc not in NOTES:
            miss += 1
            print(f"  (fallback note) {loc}")
    print(f"whatsNew set on {ok} locale(s); {miss} used fallback. ASC locales: {len(by_locale)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
