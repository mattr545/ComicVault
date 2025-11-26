//
//  CSVExporter.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Export/import a simple Comic CSV for backup and editing.
//
//  Running Edit Log
//  - 10-22-25: Initial CSV export/import helpers.
//  - 11-08-25: Header normalization.
//
//  Notes:
//  - We only round-trip a subset of fields to keep the CSV human-friendly.
//  - Extend as needed (Grade, Variant, Value, Storage, etc.).
//  - Minimal CSV escaping is implemented (commas/quotes/newlines).
//

import Foundation

// MARK: - CSVExporter facade

struct CSVExporter {

    // MARK: - CSV Export
    /// Build a CSV string from an array of comics.
    /// The header is: Title,Issue,Publisher,Notes,Barcode
    static func makeCSV(from comics: [Comic]) -> String {
        var rows: [[String]] = []
        rows.append(["Title", "Issue", "Publisher", "Notes", "Barcode"])

        for c in comics {
            let title     = c.title
            let issue     = c.issueNumber.map(String.init) ?? ""
            let publisher = c.publisher ?? ""
            let notes     = c.notes ?? ""
            let barcode   = c.barcode ?? ""
            rows.append([title, issue, publisher, notes, barcode])
        }

        return csvJoin(rows: rows)
    }

    // MARK: - CSV Import
    /// Parse a CSV string (with the exporter’s header) into `[Comic]`.
    /// Forgiving: ignores extra columns; empty cells -> nil.
    static func parseCSV(_ csvString: String) -> [Comic] {
        var comics: [Comic] = []

        // Split by line and drop the header row if present.
        let lines = csvString.components(separatedBy: .newlines).dropFirst()

        for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            let columns = csvSplit(line)
            guard columns.count >= 5 else { continue }

            let title     = columns[0]
            let issue     = Int(columns[1])
            let publisher = columns[2].isEmpty ? nil : columns[2]
            let notes     = columns[3].isEmpty ? nil : columns[3]
            let barcode   = columns[4].isEmpty ? nil : columns[4]

            // IMPORTANT: order must match Comic’s memberwise initializer.
            comics.append(
                Comic(
                    title: title,
                    issueNumber: issue,
                    publisher: publisher,
                    imageData: nil,
                    variant: nil,
                    grade: nil,
                    currentValue: nil,
                    barcode: barcode,   // <- barcode BEFORE notes
                    notes: notes        // <- then notes
                    // createdAt has a default; storageLocation defaults to nil
                )
            )
        }

        return comics
    }
}

// MARK: - CSV utilities (top-level, file-private, non-isolated)
//
// Putting these at the top level (not as static methods on a type) avoids
// accidental actor-isolation annotations and silences the warning you saw.

/// Join rows/columns into a CSV string with proper escaping.
fileprivate func csvJoin(rows: [[String]]) -> String {
    rows
        .map { $0.map(csvEscape).joined(separator: ",") }
        .joined(separator: "\n")
}

/// Escape a single CSV cell:
/// - Wrap in quotes if it contains comma, quote, or newline
/// - Double any embedded quotes per RFC 4180
fileprivate func csvEscape(_ s: String) -> String {
    if s.contains(",") || s.contains("\"") || s.contains("\n") {
        return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
    return s
}

/// Split one CSV line into columns, honoring quotes and doubled quotes.
/// Lightweight parser suitable for our simple sheet.
fileprivate func csvSplit(_ line: String) -> [String] {
    var result: [String] = []
    var current = ""
    var inQuotes = false

    var i = line.startIndex
    while i < line.endIndex {
        let ch = line[i]
        if inQuotes {
            if ch == "\"" {
                // If next char is also a quote, it's an escaped quote.
                let next = line.index(after: i)
                if next < line.endIndex, line[next] == "\"" {
                    current.append("\"")
                    i = next // skip the second quote
                } else {
                    inQuotes = false
                }
            } else {
                current.append(ch)
            }
        } else {
            if ch == "," {
                result.append(current)
                current.removeAll(keepingCapacity: true)
            } else if ch == "\"" {
                inQuotes = true
            } else {
                current.append(ch)
            }
        }
        i = line.index(after: i)
    }
    result.append(current)
    return result
}
