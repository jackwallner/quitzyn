import Foundation
import Testing
@testable import Sober

@Suite("Localization")
struct LocalizationTests {
    static let languages = ["de", "ru", "cs", "sv", "fi", "nl", "es", "da", "pl", "sk", "nb", "ro", "uk", "it", "zh-Hans"]

    private func bundle(_ language: String) -> Bundle? {
        for host in [Bundle.main] + Bundle.allBundles {
            if let path = host.path(forResource: language, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }

    @Test func everyLanguageShips() {
        for language in Self.languages {
            #expect(bundle(language) != nil, "\(language).lproj is missing")
        }
    }

    @Test func russianDayCountUsesPluralCategories() throws {
        let russian = try #require(bundle("ru"))
        let locale = Locale(identifier: "ru")
        #expect(String(localized: "\(1) days nicotine-free", bundle: russian, locale: locale) == "1 день без никотина")
        #expect(String(localized: "\(3) days nicotine-free", bundle: russian, locale: locale) == "3 дня без никотина")
        #expect(String(localized: "\(5) days nicotine-free", bundle: russian, locale: locale) == "5 дней без никотина")
    }

    @Test func trialDisclosureResolvesItsPluralInEveryLanguage() throws {
        for language in ["en"] + Self.languages {
            let host = try #require(bundle(language), "\(language).lproj is missing")
            let locale = Locale(identifier: language)
            let disclosures = [
                String(localized: "\(7)-day free trial, then \("$34.99").", bundle: host, locale: locale),
                String(localized: "\(1)-month free trial, then \("$34.99").", bundle: host, locale: locale),
                String(localized: "\(1)-year free trial, then \("$34.99").", bundle: host, locale: locale),
            ]
            for disclosure in disclosures {
                #expect(!disclosure.contains("#@"), "\(language): \(disclosure)")
                #expect(disclosure.contains("$34.99"), "\(language): \(disclosure)")
            }
        }
        let english = try #require(bundle("en"))
        #expect(String(localized: "\(7)-day free trial, then \("$34.99").", bundle: english, locale: Locale(identifier: "en")) == "7-day free trial, then $34.99.")
    }

    /// The trial sheet's two purchase errors used to be bare `String`s, so
    /// every language saw them in English.
    @Test func trialSheetErrorsAreTranslatedInEveryLanguage() throws {
        let keys = [
            String.LocalizationValue("Trial start cancelled. Tap again to continue."),
            String.LocalizationValue("Couldn't start your trial. Please try again."),
        ]
        let english = try #require(bundle("en"))
        for language in Self.languages {
            let host = try #require(bundle(language), "\(language).lproj is missing")
            for key in keys {
                let source = String(localized: key, bundle: english)
                #expect(String(localized: key, bundle: host) != source, "\(language) shows \(source) in English")
            }
        }
    }

    @Test func germanCopyIsTranslated() throws {
        let german = try #require(bundle("de"))
        #expect(String(localized: "Every nicotine-free day grows your tree.", bundle: german) == "Jeder nikotinfreie Tag lässt deinen Baum wachsen.")
        #expect(String(localized: "\(1) days free", bundle: german, locale: Locale(identifier: "de")) == "1 Tag gratis")
        #expect(String(localized: "\(7) days free", bundle: german, locale: Locale(identifier: "de")) == "7 Tage gratis")
    }

    @Test func reviewedScreenshotCopyUsesNaturalLocalizedForms() throws {
        let czech = try #require(bundle("cs"))
        let czechLocale = Locale(identifier: "cs")
        #expect(String(localized: "\(131) days nicotine-free", bundle: czech, locale: czechLocale) == "131 dní bez nikotinu")
        #expect(String(localized: "\(131) days nicotine-free label", bundle: czech, locale: czechLocale) == "131 dní bez nikotinu")

        let slovak = try #require(bundle("sk"))
        let slovakLocale = Locale(identifier: "sk")
        #expect(String(localized: "\(131) days nicotine-free", bundle: slovak, locale: slovakLocale) == "131 dní bez nikotínu")
        #expect(String(localized: "\(131) days nicotine-free label", bundle: slovak, locale: slovakLocale) == "131 dní bez nikotínu")

        let german = try #require(bundle("de"))
        let germanLocale = Locale(identifier: "de")
        let germanMinute = String(localized: "a minute", bundle: german, locale: germanLocale)
        #expect(germanMinute == "einer Minute")
        #expect(String(localized: "Your cravings usually pass in about \(germanMinute).", bundle: german, locale: germanLocale) == "Dein Verlangen klingt meist nach etwa einer Minute ab.")
        #expect(String(localized: "urges ridden out", bundle: german, locale: germanLocale) == "überstandene Verlangensmomente")

        let finnish = try #require(bundle("fi"))
        let finnishLocale = Locale(identifier: "fi")
        let finnishMinute = String(localized: "a minute", bundle: finnish, locale: finnishLocale)
        #expect(finnishMinute == "minuutissa")
        #expect(String(localized: "Your cravings usually pass in about \(finnishMinute).", bundle: finnish, locale: finnishLocale) == "Nikotiininhimo menee yleensä ohi noin minuutissa.")
        #expect(String(localized: "Your patterns", bundle: finnish, locale: finnishLocale) == "Omat toimintamallit")

        let danish = try #require(bundle("da"))
        let danishLocale = Locale(identifier: "da")
        #expect(String(localized: "Black Pine", bundle: danish, locale: danishLocale) == "Sort fyr")
        #expect(String(localized: "Windswept Bonsai", bundle: danish, locale: danishLocale) == "Vindblæst bonsai")
    }
}
