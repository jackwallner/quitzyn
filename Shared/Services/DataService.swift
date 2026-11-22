import Foundation
import SwiftData
import os

@MainActor
enum DataService {
    static let schema = Schema([
        SobrietyJourney.self,
        DailyCheckIn.self,
        JournalEntry.self,
        UnlockedAchievement.self,
        UnlockedHealthBenefit.self,
        GardenState.self,
        UserSettings.self,
        CravingEpisode.self,
    ])

    static var sharedModelContainer: ModelContainer = {
        if let container = openStore(at: containerURL, open: { makeContainer(schema: schema, url: $0) }) {
            return container
        }

        // Last-resort in-memory fallback so the app still launches
        let inMemory = ModelConfiguration("Sober", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [inMemory])
        } catch {
            let logger = Logger(subsystem: "com.jackwallner.sober", category: "DataService")
            logger.critical("ModelContainer failed even in-memory: \(String(describing: error), privacy: .public)")
            return try! ModelContainer(for: schema, configurations: [inMemory])
        }
    }()

    /// Opens the file store at `url`, or returns nil so the caller can fall
    /// back to memory. `open` is the real container init outside tests.
    ///
    /// A store only goes aside once it has failed twice with room on the disk:
    /// a failed open is not proof of corruption, and an aside store used to
    /// be read by nothing, so one bad launch hid the user's history for good.
    static func openStore(
        at url: URL,
        now: Date = .now,
        diskIsFull: (URL) -> Bool = DataService.isDiskNearlyFull,
        open: (URL) -> ModelContainer?
    ) -> ModelContainer? {
        restoreNewestAsideIfEmpty(at: url, now: now, open: open)

        if let container = open(url) ?? open(url) {
            return container
        }
        // A full disk (no room for the WAL) is not a broken store. Leave it
        // where it is; this launch runs in memory and the next one opens it.
        if diskIsFull(url) { return nil }

        // Unopenable store (corruption or a failed migration). Move it aside
        // rather than deleting it, so a user's history is still on disk for a
        // later launch to take back (`restoreNewestAsideIfEmpty`).
        // No delete fallback: if the move fails, the file stays where it is
        // and the launch falls through to the in-memory container.
        // A session with no history beats destroying the only copy of it.
        moveStore(from: url, to: URL(fileURLWithPath: url.path + ".unopenable-\(Int(now.timeIntervalSince1970))"))
        return open(url)
    }

    /// Puts the newest aside store back when the live one opens empty (or is
    /// missing), for a store that opens again now (the failure was transient,
    /// or a later build can migrate it). The empty live store is kept beside
    /// it too. A live store that will not open is left to the retry and
    /// move-aside path: swapping it out here hid its newer history under a
    /// name nothing reads back.
    private static func restoreNewestAsideIfEmpty(at url: URL, now: Date, open: (URL) -> ModelContainer?) {
        guard let aside = newestAside(of: url) else { return }
        let liveIsMissing = !FileManager.default.fileExists(atPath: url.path)
        guard liveIsMissing || storeHasHistory(at: url, open: open) == false,
              storeHasHistory(at: aside, open: open) == true
        else { return }
        moveStore(from: url, to: URL(fileURLWithPath: url.path + ".replaced-\(Int(now.timeIntervalSince1970))"))
        moveStore(from: aside, to: url)
    }

    private static func newestAside(of url: URL) -> URL? {
        let folder = url.deletingLastPathComponent()
        let prefix = url.lastPathComponent + ".unopenable-"
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let newest = names
            .filter { $0.hasPrefix(prefix) && Int($0.dropFirst(prefix.count)) != nil }
            .max { (Int($0.dropFirst(prefix.count)) ?? 0) < (Int($1.dropFirst(prefix.count)) ?? 0) }
        return newest.map { folder.appendingPathComponent($0) }
    }

    /// Nil when there is no store at `url` or it will not open. The container
    /// is released before returning, so its files can be moved.
    private static func storeHasHistory(at url: URL, open: (URL) -> ModelContainer?) -> Bool? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return autoreleasepool {
            guard let container = open(url) else { return nil }
            let context = ModelContext(container)
            let journeys = (try? context.fetchCount(FetchDescriptor<SobrietyJourney>())) ?? 0
            let checkIns = (try? context.fetchCount(FetchDescriptor<DailyCheckIn>())) ?? 0
            return journeys + checkIns > 0
        }
    }

    /// Moves a store with its `-wal` and `-shm` files.
    private static func moveStore(from source: URL, to destination: URL) {
        for suffix in ["", "-wal", "-shm"] {
            let file = URL(fileURLWithPath: source.path + suffix)
            guard FileManager.default.fileExists(atPath: file.path) else { continue }
            try? FileManager.default.moveItem(at: file, to: URL(fileURLWithPath: destination.path + suffix))
        }
    }

    /// Under 20 MB free: too little for SQLite to open a store and its WAL.
    nonisolated static func isDiskNearlyFull(_ url: URL) -> Bool {
        let folder = url.deletingLastPathComponent()
        let free = try? folder.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity
        return free.map { $0 < 20_000_000 } ?? false
    }

    static func makeContainer(schema: Schema, url: URL) -> ModelContainer? {
        let config = ModelConfiguration(
            "Sober",
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        return try? ModelContainer(for: schema, configurations: [config])
    }

    /// Bumped to v2 when the Garden schema was reshaped (species → items).
    /// Old `Sober.store` is left dormant on disk so a future migration could
    /// recover salvageable fields (e.g. SobrietyJourney start date) if needed.
    private static var containerURL: URL {
        AppGroup.containerURL.appendingPathComponent("Sober.v2.store")
    }
}
