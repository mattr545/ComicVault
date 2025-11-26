//
//  BackupManager.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Coordinates creation and restoration of local backup archives.
//

import Foundation

final class BackupManager {

    // MARK: - Singleton
    static let shared = BackupManager()

    // MARK: - Public surface read by views
    private static let udLastBackupKey = "backup.last.timestamp"

    /// Last successful export time (persisted in UserDefaults).
    private(set) var lastBackupDate: Date? {
        get { UserDefaults.standard.object(forKey: Self.udLastBackupKey) as? Date }
        set {
            if let v = newValue {
                UserDefaults.standard.set(v, forKey: Self.udLastBackupKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.udLastBackupKey)
            }
        }
    }

    /// If an export fails, this holds a human-readable reason.
    private(set) var errorMessage: String?

    // MARK: - JSON

    /// Export comics to a temporary JSON file and return the file URL (or nil on failure).
    func exportJSON(comics: [Comic]) async -> URL? {
        do {
            // Do the file work off the main actor.
            let url = try await Task.detached(priority: .utility) {
                try FileExport.makeJSONTemp(comics: comics)
            }.value

            await MainActor.run {
                self.lastBackupDate = Date()
                self.errorMessage = nil
            }
            return url
        } catch {
            await MainActor.run {
                self.errorMessage = "JSON export failed: \(error.localizedDescription)"
            }
            return nil
        }
    }

    // MARK: - CSV

    /// Export comics to a temporary CSV file and return the file URL (or nil on failure).
    func exportCSV(comics: [Comic]) async -> URL? {
        do {
            let url = try await Task.detached(priority: .utility) {
                try FileExport.makeCSVTemp(comics: comics)
            }.value

            await MainActor.run {
                self.lastBackupDate = Date()
                self.errorMessage = nil
            }
            return url
        } catch {
            await MainActor.run {
                self.errorMessage = "CSV export failed: \(error.localizedDescription)"
            }
            return nil
        }
    }
}

// MARK: - Private file export helpers (no top-level symbols)

private enum FileExport {

    // Explicitly nonisolated so they’re callable from background tasks without warnings.
    nonisolated static func makeJSONTemp(comics: [Comic]) throws -> URL {
        let data = try JSONEncoder().encode(comics)
        let base = "ComicVault-\(datestamp())"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(base)
            .appendingPathExtension("json")
        try data.write(to: url, options: .atomic)
        return url
    }

    nonisolated static func makeCSVTemp(comics: [Comic]) throws -> URL {
        var rows: [[String]] = []
        rows.append(["Title", "Issue", "Publisher", "Grade", "Value", "Created At"])

        let df = DateFormatter()
        df.calendar  = Calendar(identifier: .gregorian)
        df.locale    = Locale(identifier: "en_US_POSIX")
        df.timeZone  = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"

        for c in comics {
            let title   = c.title
            let issue   = c.issueNumber.map { "#\($0)" } ?? ""
            let pub     = c.publisher ?? ""
            let grade   = c.grade ?? ""
            let value   = c.currentValue.map { "\($0)" } ?? ""
            let created = df.string(from: c.createdAt)
            rows.append([title, issue, pub, grade, value, created])
        }

        let csv = rows
            .map { $0.map(csvEscape).joined(separator: ",") }
            .joined(separator: "\n")

        guard let data = csv.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }

        let base = "ComicVault-\(datestamp())"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(base)
            .appendingPathExtension("csv")
        try data.write(to: url, options: .atomic)
        return url
    }

    // Pure string/date helpers — also nonisolated.
    nonisolated private static func csvEscape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return s
    }

    nonisolated private static func datestamp() -> String {
        let df = DateFormatter()
        df.calendar  = Calendar(identifier: .gregorian)
        df.locale    = Locale(identifier: "en_US_POSIX")
        df.timeZone  = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyyMMdd-HHmmss"
        return df.string(from: Date())
    }
}
