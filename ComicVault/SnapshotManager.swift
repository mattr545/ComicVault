//
//  SnapshotManager.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Manages daily portfolio snapshots (local + optional iCloud Drive).
//
//  Running Edit Log
//  - 10-22-25: Added actor-based worker and pruning.
//  - 11-07-25: Integrated with app lifecycle.
//  - 11-08-25: Header normalization.
//
//

import Foundation
import Combine

// MARK: - Background worker (all disk I/O happens here)

actor SnapshotWorker {

    // Fresh formatter each call (no shared mutable state), UTC yyyy-MM-dd.
    private func dayFormatter() -> DateFormatter {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df
    }

    // Documents/Snapshots (or iCloud Drive’s Documents/Snapshots) folder.
    private func folderURL() throws -> URL {
        let fm = FileManager.default

        // Read the switch from UserDefaults here so we don’t touch main-actor state.
        let useICloud = UserDefaults.standard.bool(forKey: "useICloudSync")

        let base: URL
        if useICloud,
           let ubiq = fm.url(forUbiquityContainerIdentifier: "iCloud.com.MattRussell.ComicVault") {
            base = ubiq.appendingPathComponent("Documents", isDirectory: true)
        } else {
            guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw CocoaError(.fileNoSuchFile)
            }
            base = docs
        }

        let folderName = "Snapshots"
        let folder = base.appendingPathComponent(folderName, isDirectory: true)
        if !fm.fileExists(atPath: folder.path) {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private func utcDayString(from date: Date = Date()) -> String {
        dayFormatter().string(from: date)
    }

    private func fileName(for day: String) -> String {
        let prefix = "Snapshot_"
        let ext    = "json"
        return "\(prefix)\(day).\(ext)"
    }

    /// Write/overwrite today’s snapshot file with the full `[Comic]`.
    /// Returns the URL if successful.
    func writeSnapshot(for comics: [Comic]) async throws -> URL {
        let fm     = FileManager.default
        let folder = try folderURL()
        let day    = utcDayString()
        let url    = folder.appendingPathComponent(fileName(for: day), isDirectory: false)

        let data = try JSONEncoder().encode(comics)
        try data.write(to: url, options: .atomic)

        // Best-effort: harden on main actor if FileProtection helper exists.
        await MainActor.run {
            try? FileProtection.harden(at: url)
        }

        if fm.isUbiquitousItem(at: url) {
            try? fm.setUbiquitous(true, itemAt: url, destinationURL: url)
        }

        return url
    }

    /// Delete old snapshot files based on retention (in days). `nil` = lifetime.
    func pruneOldSnapshots(retentionDays: Int?) throws {
        guard let retention = retentionDays, retention > 0 else { return }

        let fm     = FileManager.default
        let folder = try folderURL()
        let cal    = Calendar(identifier: .gregorian)
        let cutoff = cal.date(byAdding: .day, value: -retention, to: Date()) ?? .distantPast
        let cutKey = utcDayString(from: cutoff)

        var urls = try fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let ext    = "json"
        let prefix = "Snapshot_"

        urls = urls.filter {
            $0.pathExtension.lowercased() == ext &&
            $0.lastPathComponent.hasPrefix(prefix)
        }

        for url in urls {
            let base = url.deletingPathExtension().lastPathComponent
            if let tail = base.split(separator: "_").last,
               String(tail) < cutKey {
                try? fm.removeItem(at: url)
            }
        }
    }

    /// Load **all** snapshots and compute the per-day totals using the provided reducer.
    func loadAllEntries(
        computeTotal: @Sendable ([Comic]) -> Double
    ) async throws -> [PortfolioEntry] {

        let fm     = FileManager.default
        let folder = try folderURL()

        var urls = try fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let ext    = "json"
        let prefix = "Snapshot_"

        urls = urls
            .filter { $0.pathExtension.lowercased() == ext && $0.lastPathComponent.hasPrefix(prefix) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var results: [PortfolioEntry] = []
        let df  = dayFormatter()
        let cal = Calendar(identifier: .gregorian)

        for url in urls {
            do {
                let data   = try Data(contentsOf: url)
                let comics = try JSONDecoder().decode([Comic].self, from: data)
                let total  = computeTotal(comics)

                // Prefer day from filename; fallback to file metadata; normalize to startOfDay.
                let parsedFromName: Date? = {
                    let base = url.deletingPathExtension().lastPathComponent  // "Snapshot_YYYY-MM-DD"
                    guard let tail = base.split(separator: "_").last else { return nil }
                    return df.date(from: String(tail))
                }()

                let fileDate = try? url
                    .resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate

                let source = parsedFromName ?? fileDate ?? Date()
                let start  = cal.startOfDay(for: source)

                // Create PortfolioEntry on MainActor (if it's main-actor isolated),
                // then append to our local results inside this actor.
                let entry = await MainActor.run {
                    PortfolioEntry(date: start, total: total)
                }
                results.append(entry)
            } catch {
                // Skip corrupt/partial files; keep going.
                continue
            }
        }

        return results
    }

    // Helper exposed to the manager to reuse consistent day key (UTC).
    func todayUTCString() -> String { utcDayString() }
}

// MARK: - SnapshotManager (UI-facing)

@MainActor
final class SnapshotManager: ObservableObject {

    /// Published series for charts (date, total value in USD).
    @Published private(set) var entries: [PortfolioEntry] = []

    private let worker = SnapshotWorker()

    // Rebuild the in-memory series from all snapshot files on disk.
    func refresh() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }

            let compute: @Sendable ([Comic]) -> Double = { comics in
                comics.compactMap { $0.currentValue }.reduce(0, +)
            }

            do {
                let series = try await self.worker.loadAllEntries(computeTotal: compute)
                await MainActor.run { self.entries = series }
            } catch {
                await MainActor.run { self.entries = [] }
            }
        }
    }

    /// Take a snapshot for today’s UTC day if we haven’t already, then refresh.
    func performDailySnapshotIfNeeded(comics: [Comic]) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }

            let ud    = UserDefaults.standard
            let today = await self.worker.todayUTCString()

            let lastKey      = "SNAP_LAST_UTC"
            let retentionKey = "SNAP_RETENTION_DAYS"

            if ud.string(forKey: lastKey) != today {
                if (try? await self.worker.writeSnapshot(for: comics)) != nil {
                    ud.set(today, forKey: lastKey)
                }
            }

            let retention = ud.object(forKey: retentionKey) as? Int
            try? await self.worker.pruneOldSnapshots(retentionDays: retention)

            await self.refreshAsync()
        }
    }

    /// Manual snapshot (always writes today’s file, overwriting if present), then refresh.
    func takeSnapshotNow(comics: [Comic]) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }

            let ud    = UserDefaults.standard
            let today = await self.worker.todayUTCString()

            let lastKey      = "SNAP_LAST_UTC"
            let retentionKey = "SNAP_RETENTION_DAYS"

            if (try? await self.worker.writeSnapshot(for: comics)) != nil {
                ud.set(today, forKey: lastKey)
            }

            let retention = ud.object(forKey: retentionKey) as? Int
            try? await self.worker.pruneOldSnapshots(retentionDays: retention)

            await self.refreshAsync()
        }
    }

    // Convenience to await `refresh()` from a detached task.
    private func refreshAsync() async {
        await withCheckedContinuation { continuation in
            self.refresh()
            continuation.resume()
        }
    }
}
