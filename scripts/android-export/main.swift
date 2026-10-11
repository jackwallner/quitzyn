import AppKit
import Foundation
import SwiftUI

func colorHex(_ color: Color) -> String {
    guard let color = NSColor(color).usingColorSpace(.sRGB) else { return "#000000" }
    let red = Int((color.redComponent * 255).rounded())
    let green = Int((color.greenComponent * 255).rounded())
    let blue = Int((color.blueComponent * 255).rounded())
    return String(format: "#%02X%02X%02X", red, green, blue)
}

func writeJSON(_ object: Any, to path: String) throws {
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    try (data + Data("\n".utf8)).write(to: url, options: .atomic)
}

// Elapsed time is a progress marker, not a measurement of someone's recovery.
// Keep the source IDs, thresholds and citations without exporting guarantees.
let safeMilestoneCopy: [String: (title: String, summary: String, detail: String)] = [
    "heart-rate-steadies": ("Heart rate and nicotine", "Learn how nicotine affects your pulse.", "Nicotine can raise heart rate and blood pressure for a while after each dose. This app does not measure your pulse or tell you when it has changed."),
    "nicotine-falling": ("Nicotine levels", "Learn how the body processes nicotine.", "Nicotine has a short half-life, but how fast it clears varies with dose and individual factors. A timer cannot measure the nicotine in your body."),
    "nicotine-cleared": ("Clearing nicotine", "Learn about nicotine and cotinine.", "The body breaks nicotine down into cotinine, which lingers longer. Your day count is not a test result and does not show when either has cleared."),
    "taste-smell": ("Taste and smell", "Notice your own senses.", "Some people notice food tasting fuller or smells seeming sharper after they stop. The timing and experience vary, and this milestone does not promise a change."),
    "cravings-peak": ("The first few days", "Withdrawal often feels strongest early.", "Many people find the first several days the hardest, and cravings often get shorter and less frequent after that. Experiences vary; speak with a clinician if withdrawal worries you."),
    "sleep-focus": ("Sleep and focus", "Reflect on your own experience.", "Sleep and concentration can shift while your routine adjusts to life without nicotine. Individual experiences vary; this app does not assess sleep or cognitive function."),
    "gums-healing": ("Your mouth and pouches", "Learn about pouches and oral health.", "Research links holding pouches against the gums with irritation in the mouth. Your elapsed time does not establish a change in your gums. Ask a dentist about any concerns."),
    "mood-stabilizes": ("Mood and withdrawal", "Information, not a diagnosis.", "Irritability and anxiety are common in early nicotine withdrawal and often ease with time. This app does not assess or treat mood. Speak with a qualified clinician about symptoms."),
    "blood-pressure": ("Blood pressure information", "Learn about nicotine and heart health.", "Nicotine can raise blood pressure, but responses and timing vary. This app does not measure blood pressure or predict when it will change."),
    "circulation": ("Circulation information", "Read the cited background information.", "Nicotine narrows blood vessels while it is active. Your counter is not a measurement of circulation, energy, or cardiovascular recovery."),
    "oral-health": ("Six-Month Milestone", "A longer-term progress marker.", "Around six months, take stock of the routines and personal progress that brought you here. Ask a dentist about your own oral health."),
    "stress-resilience": ("Stress and nicotine", "Notice changes without a promised timeline.", "Many people expect nicotine to relieve stress, and some find stress feels different months after stopping. Changes vary, and this milestone does not measure stress."),
    "heart-risk-drops": ("One-Year Milestone", "A year of personal progress.", "A year is a meaningful progress marker, not a declaration of full recovery. Discuss your individual health and risks with a qualified clinician."),
]

let output = CommandLine.arguments[1]
let parityOutput = CommandLine.arguments[2]
let content: [String: Any] = [
    "schemaVersion": 1,
    "healthBenefits": HealthBenefitCatalog.all.map { benefit -> [String: Any] in
        guard let copy = safeMilestoneCopy[benefit.id] else {
            fatalError("Review Android health wording for the new milestone \(benefit.id) before exporting.")
        }
        return ["id": benefit.id, "hoursRequired": benefit.hoursRequired, "title": copy.title,
                "summary": copy.summary, "detail": copy.detail, "sourceLabel": benefit.sourceLabel,
                "sourceURL": benefit.sourceURL.map { $0.absoluteString as Any } ?? NSNull()]
    },
    "achievements": AchievementCatalog.all.map { achievement -> [String: Any] in
        ["id": achievement.id, "title": achievement.title, "description": achievement.description,
         "kind": achievement.kind.rawValue, "dayThreshold": achievement.dayThreshold, "icon": achievement.icon]
    },
    "journalPrompts": JournalPromptCatalog.all.map { prompt -> [String: Any] in
        ["id": prompt.id, "kind": prompt.kind.rawValue, "text": prompt.text]
    },
    "species": GardenItemCatalog.all.map { item -> [String: Any] in
        ["id": item.id, "displayName": item.displayName, "description": item.description,
         "order": item.milestoneDays, "icon": item.sfSymbol, "colors": item.colors.map(colorHex)]
    },
    "stages": BonsaiStage.allCases.map { stage -> [String: Any] in
        ["id": stage.rawValue, "title": stage.title, "dayThreshold": stage.dayThreshold,
         "growthMessage": stage.growthMessage]
    },
    "vocabulary": [
        "substance": HabitVocabulary.substance, "habitGerund": HabitVocabulary.habitGerund,
        "habitInstance": HabitVocabulary.habitInstance, "urgeNoun": HabitVocabulary.urgeNoun,
        "urgeNounPlural": HabitVocabulary.urgeNounPlural,
        "typicalUrgeSeconds": HabitVocabulary.typicalUrgeSeconds,
        "minUrgeSeconds": HabitVocabulary.minUrgeSeconds, "maxUrgeSeconds": HabitVocabulary.maxUrgeSeconds,
        "triggers": HabitVocabulary.triggers, "reasonPlaceholder": HabitVocabulary.reasonPlaceholder,
        "cleanDayAdjective": HabitVocabulary.cleanDayAdjective,
        "priceComparisonMaxDays": HabitVocabulary.priceComparisonMaxDays,
    ],
    "coachLines": [0, 20, 35, 65, 95].map { CravingCoach.line(elapsed: $0, target: 100) },
]

let days = [-3, 0, 1, 2, 3, 6, 7, 13, 14, 29, 30, 59, 60, 89, 90, 179, 180, 364, 365, 366, 400, 730, 731, 1080]
let growth: [[String: Any]] = days.map { day in
    let cycle = GardenService.cycleProgress(forDays: day)
    return ["days": day, "dayInCycle": cycle.dayInCycle, "completed": cycle.completed,
            "stage": GardenService.stage(forDays: day).rawValue]
}
let carryover: [[String: Any]] = days.flatMap { day in
    [0, 5, 20, 364].map { inherited -> [String: Any] in
        ["days": day, "carryover": inherited,
         "treeDays": GardenService.treeDays(streakDays: day, carryover: inherited)]
    }
}
let coach: [[String: Any]] = [0, 60, 180, 600].flatMap { target in
    [0, 1, 9, 14, 15, 34, 35, 59, 60, 84, 85, 99, 100, 180, 600].map { elapsed in
        ["elapsed": elapsed, "target": target, "line": CravingCoach.line(elapsed: elapsed, target: target)]
    }
}
let parity: [String: Any] = [
    "counts": ["healthBenefits": HealthBenefitCatalog.all.count, "achievements": AchievementCatalog.all.count,
               "journalPrompts": JournalPromptCatalog.all.count, "species": GardenItemCatalog.all.count,
               "stages": BonsaiStage.allCases.count],
    "growth": growth, "carryover": carryover, "coach": coach,
]
try writeJSON(content, to: output)
try writeJSON(parity, to: parityOutput)
print("Exported \(HealthBenefitCatalog.all.count) health milestones, \(AchievementCatalog.all.count) achievements, \(JournalPromptCatalog.all.count) prompts, \(GardenItemCatalog.all.count) species and Swift parity fixtures.")
