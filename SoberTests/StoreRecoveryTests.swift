import Foundation
import SwiftData
import Testing
@testable import Sober

/// B1 (2026-11-20 catalog): one failed open used to move the store aside for
/// good, so a transient failure looked to the user like a brand new app.
@MainActor
@Suite(.serialized)
struct StoreRecoveryTests {
    private let folder: URL
    private let url: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("store-recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appendingPathComponent("Sober.v2.store")
    }

    private func realOpen(_ url: URL) -> ModelContainer? {
        DataService.makeContainer(schema: DataService.schema, url: url)
    }

    /// Writes a store holding one journey at `target`, then lets it close.
    private func seedStore(at target: URL, startDaysAgo: Int) throws {
        try autoreleasepool {
            guard let container = realOpen(target) else { throw CocoaError(.fileWriteUnknown) }
            let context = ModelContext(container)
            context.insert(SobrietyJourney(startDate: DateHelpers.daysAgo(startDaysAgo)))
            context.insert(DailyCheckIn(day: DateHelpers.daysAgo(startDaysAgo), wasLogged: true))
            try context.save()
        }
    }

    private func journeyCount(in container: ModelContainer?) -> Int {
        guard let container else { return -1 }
        return (try? ModelContext(container).fetchCount(FetchDescriptor<SobrietyJourney>())) ?? -1
    }

    private func startDaysAgo(in container: ModelContainer?) -> Int? {
        guard let container,
              let journey = try? ModelContext(container).fetch(FetchDescriptor<SobrietyJourney>()).first
        else { return nil }
        return DateHelpers.daysBetween(journey.startDate, .now)
    }

    private func asideFiles() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { $0.contains(".unopenable-") }
    }

    @Test func aFailedFirstOpenRetriesBeforeMovingTheStore() throws {
        try seedStore(at: url, startDaysAgo: 120)
        var attempts = 0
        let container = DataService.openStore(at: url) { target in
            attempts += 1
            return attempts == 1 ? nil : realOpen(target)
        }
        #expect(journeyCount(in: container) == 1)
        #expect(asideFiles().isEmpty)
    }

    @Test func aFullDiskLeavesTheStoreInPlace() throws {
        try seedStore(at: url, startDaysAgo: 120)
        let container = DataService.openStore(at: url, diskIsFull: { _ in true }) { _ in nil }
        #expect(container == nil)
        #expect(asideFiles().isEmpty)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func anEmptyStoreTakesBackTheHistoryMovedAside() throws {
        try seedStore(at: URL(fileURLWithPath: url.path + ".unopenable-1700000000"), startDaysAgo: 200)
        let container = DataService.openStore(at: url, open: realOpen)
        #expect(journeyCount(in: container) == 1)
        #expect(startDaysAgo(in: container) == 200)
    }

    @Test func aStoreWithItsOwnHistoryIsNotReplaced() throws {
        try seedStore(at: URL(fileURLWithPath: url.path + ".unopenable-1700000000"), startDaysAgo: 200)
        try seedStore(at: url, startDaysAgo: 5)
        let container = DataService.openStore(at: url, open: realOpen)
        #expect(startDaysAgo(in: container) == 5)
        #expect(!asideFiles().isEmpty)
    }

    /// A live store that fails to open while an older one sits aside is not
    /// swapped for the older one: it holds the newer history, so it goes
    /// through the retry and, if it still fails, aside as the newest store,
    /// where a later launch takes it back.
    @Test func aLiveStoreThatWillNotOpenIsNotSwappedForAnOlderOne() throws {
        try seedStore(at: URL(fileURLWithPath: url.path + ".unopenable-1700000000"), startDaysAgo: 200)
        try seedStore(at: url, startDaysAgo: 5)
        // The live store fails the probe, the open and its retry; the fourth
        // open is the fresh store after the move aside.
        var liveOpens = 0
        do {
            let failingLive = DataService.openStore(at: url, diskIsFull: { _ in false }) { target in
                guard target == url else { return realOpen(target) }
                liveOpens += 1
                return liveOpens <= 3 ? nil : realOpen(target)
            }
            #expect(journeyCount(in: failingLive) == 0, "this launch runs on a fresh store")
        }

        // Next launch, the transient failure has passed.
        let next = DataService.openStore(at: url, open: realOpen)
        #expect(startDaysAgo(in: next) == 5)
    }

    @Test func aCorruptStoreIsStillMovedAsideAndAFreshOneOpens() throws {
        try Data("not a database".utf8).write(to: url)
        let container = DataService.openStore(at: url, open: realOpen)
        #expect(journeyCount(in: container) == 0)
        #expect(!asideFiles().isEmpty)
    }
}
