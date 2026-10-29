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

    @Test func germanCopyIsTranslated() throws {
        let german = try #require(bundle("de"))
        #expect(String(localized: "Every nicotine-free day grows your tree.", bundle: german) == "Jeder nikotinfreie Tag lässt deinen Baum wachsen.")
        #expect(String(localized: "\(1) days free", bundle: german, locale: Locale(identifier: "de")) == "1 Tag gratis")
        #expect(String(localized: "\(7) days free", bundle: german, locale: Locale(identifier: "de")) == "7 Tage gratis")
    }
}
