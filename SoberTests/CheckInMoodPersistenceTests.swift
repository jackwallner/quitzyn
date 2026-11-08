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

/// The Home note sheet opens prefilled, so its Save has to be able to clear
/// what it shows. `checkIn(mood:note:)` treats nil as "keep", which silently
/// brought a deleted note or deselected mood back.
@Suite("Clearing today's mood or note in the check-in sheet sticks")
@MainActor
struct CheckInDetailClearTests {
    private func service() throws -> (CheckInService, ModelContainer) {
        let container = try ModelContainer(
            for: DailyCheckIn.self, SobrietyJourney.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let defaults = UserDefaults(suiteName: "detail-\(UUID().uuidString)")!
        return (CheckInService(context: container.mainContext, dayKeyDefaults: defaults), container)
    }

    @Test func clearedNoteAndMoodStayCleared() throws {
        let (checkIns, container) = try service()
        checkIns.checkIn(mood: 4, note: "Walked it off.")

        checkIns.setDetails(mood: nil, note: nil)

        #expect(checkIns.saved().mood == nil)
        #expect(checkIns.saved().note == nil)
        #expect(checkIns.hasCheckedIn())
        _ = container
    }

    @Test func editKeepsTheDayLoggedAndSober() throws {
        let (checkIns, container) = try service()
        checkIns.checkIn()

        checkIns.setDetails(mood: 5, note: "Clear head.")

        #expect(checkIns.saved().mood == 5)
        #expect(checkIns.saved().note == "Clear head.")
        #expect(checkIns.hasCheckedIn())
        #expect(!checkIns.loggedSlip())
        _ = container
    }

    @Test func emptyEditOnAnUnloggedDayWritesNothing() throws {
        let (checkIns, container) = try service()

        checkIns.setDetails(mood: nil, note: nil)

        #expect(!checkIns.hasCheckedIn())
        _ = container
    }
}
