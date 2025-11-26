//
//  MetadataLookup.swift
//  ComicVault
//
//  File created on 10/18/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: High-level entry points for online metadata search (e.g., ComicVine).
//
//  Running Edit Log
//  - 10/19/25: Reformatted and bug error
//

import Foundation

/// Basic comic metadata returned from a lookup service.

// === STRUCT: ComicMetadata ===
// STRUCT `ComicMetadata`: A data type or view that groups related fields/logic.
// This block defines how `ComicMetadata` behaves and is used throughout the app.
struct ComicMetadata {
    var title: String?
    var publisher: String?
    var issueNumber: Int?
    var notes: String?
}

/// Errors the lookup layer might throw.

// === ENUM: MetadataLookupError: ===
// ENUM `MetadataLookupError:`: A closed set of cases.
// This block groups related constants or modes in a type-safe way.
enum MetadataLookupError: Error, LocalizedError {
    case invalidBarcode
    case notFound
    case networkUnavailable
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .invalidBarcode: return "The barcode format isn’t valid."
        case .notFound: return "No metadata found for this code."
        case .networkUnavailable: return "Network unavailable."
        case .parsingFailed: return "Couldn’t parse the response."
        }
    }
}

/// Protocol to make the lookup layer swappable (stub now, real API later).

// === PROTOCOL: MetadataLookupServing ===
// PROTOCOL `MetadataLookupServing`: A set of requirements other types can adopt.
// This is used for abstraction and testability.
protocol MetadataLookupServing {
    /// Looks up metadata for a barcode (EAN/UPC/ISBN/QR string).
// MARK: - Function: lookup
    func lookup(barcode: String) async throws -> ComicMetadata
}

/// Concrete lookup service.
/// - Right now: local heuristics only (no network).
/// - Later: add real web calls (ComicVine/OpenLibrary/etc) behind the same API.
final class MetadataLookupService: MetadataLookupServing {
// MARK: - Function: lookup
    func lookup(barcode: String) async throws -> ComicMetadata {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MetadataLookupError.invalidBarcode }

        // Simple digit-only extraction for heuristics; keep original around for QR-like codes.
        let digits = trimmed.filter(\.isNumber)

        // Heuristic examples (offline):
        // - EAN-13 / ISBN-13: 13 digits, often starts with 978/979; we’ll fake a reasonable guess.
        if digits.count == 13 {
            if digits.hasPrefix("978") || digits.hasPrefix("979") {
                // Pretend it's an ISBN-13 that maps to a common TPB
                return ComicMetadata(
                    title: "Collected Edition",
                    publisher: "Unknown Publisher",
                    issueNumber: nil,
                    notes: "Auto-filled from ISBN-like barcode \(trimmed)"
                )
            } else {
                // Generic EAN-13
                return ComicMetadata(
                    title: nil,
                    publisher: "EAN Publisher",
                    issueNumber: nil,
                    notes: "Auto-filled from EAN-13 \(trimmed)"
                )
            }
        }

        // UPC-A: 12 digits
        if digits.count == 12 {
            return ComicMetadata(
                title: nil,
                publisher: "UPC Publisher",
                issueNumber: nil,
                notes: "Auto-filled from UPC-A \(trimmed)"
            )
        }

        // EAN-8: 8 digits
        if digits.count == 8 {
            return ComicMetadata(
                title: nil,
                publisher: nil,
                issueNumber: nil,
                notes: "Auto-filled from EAN-8 \(trimmed)"
            )
        }

        // If it's not a common retail code, return a neutral default.
        // (For QR or custom codes, we can later parse embedded JSON or URLs here.)
        if digits.isEmpty == false {
            return ComicMetadata(
                title: nil,
                publisher: nil,
                issueNumber: nil,
                notes: "Unrecognized numeric code \(trimmed)"
            )
        }

        // Non-numeric (likely QR text). Keep as note so it’s not lost.
        return ComicMetadata(
            title: nil,
            publisher: nil,
            issueNumber: nil,
            notes: "Scanned: \(trimmed)"
        )
    }
}
