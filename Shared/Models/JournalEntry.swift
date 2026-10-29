import Foundation
import SwiftData

enum JournalKind: String, Codable, CaseIterable {
    case daily
    case challenge
    case freeform
}

@Model
final class JournalEntry {
    var id: UUID
    var createdAt: Date
    var promptID: String?
    var kindRaw: String
    var text: String
    var feeling: String?   // e.g. "good", "excellent", "neutral"

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        promptID: String? = nil,
        kind: JournalKind = .daily,
        text: String,
        feeling: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.promptID = promptID
        self.kindRaw = kind.rawValue
        self.text = text
        self.feeling = feeling
    }

    var kind: JournalKind { JournalKind(rawValue: kindRaw) ?? .daily }
}

extension JournalEntry {
    /// Stored feeling tags stay stable while their labels follow the app language.
    static func feelingLabel(_ feeling: String) -> String {
        switch feeling {
        case "excellent": String(localized: "Excellent")
        case "good": String(localized: "Good")
        case "neutral": String(localized: "Neutral")
        case "okay": String(localized: "OK")
        case "tough": String(localized: "Tough")
        case "rough": String(localized: "Rough")
        default: feeling
        }
    }
}
