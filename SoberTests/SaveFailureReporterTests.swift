import Foundation
import SwiftData
import Testing
@testable import Sober

@MainActor
@Suite(.serialized)
struct SaveFailureReporterTests {
    @Test func cravingSaveReportsNothingWhenStoreIsFine() throws {
        let schema = Schema([CravingEpisode.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        SaveFailureReporter.shared.message = nil
        CravingService(context: container.mainContext).record(
            startedAt: .now.addingTimeInterval(-120), secondsElapsed: 120, outcome: .rodeItOut, intensity: 3
        )
        #expect(SaveFailureReporter.shared.message == nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<CravingEpisode>()) == 1)
    }

    @Test func reportedFailureProducesPlainMessage() {
        SaveFailureReporter.shared.message = nil
        SaveFailureReporter.shared.report(CocoaError(.fileWriteOutOfSpace))
        let message = SaveFailureReporter.shared.message ?? ""
        #expect(message.contains("could not be saved"))
        #expect(!message.contains("—"))
        SaveFailureReporter.shared.message = nil
    }
}
