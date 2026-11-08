import Testing
import Foundation
import SwiftData
@testable import Sober

/// The check-in sheet opens on today's saved mood, and a changed mood is
/// there again after the app is reopened.
@Suite("Today's mood survives a save and a reopen")
@MainActor
struct CheckInMoodPersistenceTests {
    private let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("mood-\(UUID().uuidString).store")
    private let defaults = UserDefaults(suiteName: "mood-\(UUID().uuidString)")!

    private func service() throws -> (CheckInService, ModelContainer) {
        let container = try ModelContainer(
            for: DailyCheckIn.self, SobrietyJourney.self,
            configurations: ModelConfiguration(url: url)
        )
        return (CheckInService(context: container.mainContext, dayKeyDefaults: defaults), container)
    }

    @Test func seededMoodReadsBackAndAChangeSurvivesReopen() throws {
        var (checkIns, container) = try service()
        checkIns.fillJourney(start: DateHelpers.daysAgo(24), through: .now)
        checkIns.checkIn(for: DateHelpers.daysAgo(0), wasSober: true, mood: 5, note: "Feeling steady.")
        #expect(checkIns.saved().mood == 5)

        checkIns.checkIn(mood: 4, note: "Feeling steady.")
        #expect(checkIns.saved().mood == 4)
        _ = container

        (checkIns, container) = try service()
        #expect(checkIns.saved().mood == 4)
        #expect(checkIns.saved().note == "Feeling steady.")
    }
}
