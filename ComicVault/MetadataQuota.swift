//
//  MetadataQuota.swift
//  ComicVault
//
//  File created on 10/18/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Tracks and enforces remote metadata API usage limits.
//
//  Running Edit Log
//  - 10-22-25: New. Manages 10-lookup trial and local cache.
//
//  NOTES
//  Keeps a small local cache of barcode → suggestion to avoid repeated network calls,
//  and enforces a simple "10 unique successful lookups" cap for the embedded key.
//  Title-only searches do not consume the embedded quota.
//

import Foundation

struct MetadataQuota {
    private static let countedBarcodesKey = "meta.counted.barcodes"
    private static let suggestionCacheKey = "meta.cache.suggestions"
    private static let capKey              = "meta.cap.limit"
    private static let defaultCap          = 10

    /// Set the trial cap. Defaults to 10 if unset.
    static var cap: Int {
        get { UserDefaults.standard.integer(forKey: capKey) == 0 ? defaultCap : UserDefaults.standard.integer(forKey: capKey) }
        set { UserDefaults.standard.set(newValue, forKey: capKey) }
    }

    /// True if another unique lookup may be counted.
    static func canCountNewLookup() -> Bool {
        countedBarcodes().count < cap
    }

    /// Returns true if this barcode has already been counted.
    static func alreadyCounted(barcode: String) -> Bool {
        countedBarcodes().contains(barcode)
    }

    /// Record that this barcode produced a successful network lookup.
    static func recordSuccess(barcode: String) {
        var set = countedBarcodes()
        if !set.contains(barcode) {
            set.insert(barcode)
            saveCountedBarcodes(set)
        }
    }

    // MARK: - Cache

    static func cachedSuggestion(for barcode: String) -> MetadataSuggestion? {
        guard
            let blob = UserDefaults.standard.data(forKey: suggestionCacheKey),
            let map = try? JSONDecoder().decode([String: MetadataSuggestion].self, from: blob)
        else { return nil }
        return map[barcode]
    }

    static func cacheSuggestion(_ suggestion: MetadataSuggestion, barcode: String) {
        var map: [String: MetadataSuggestion] = [:]
        if let blob = UserDefaults.standard.data(forKey: suggestionCacheKey),
           let existing = try? JSONDecoder().decode([String: MetadataSuggestion].self, from: blob) {
            map = existing
        }
        var s = suggestion
        if s.barcode == nil { s.barcode = barcode }
        map[barcode] = s
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: suggestionCacheKey)
        }
    }

    // MARK: - Private storage helpers

    private static func countedBarcodes() -> Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: countedBarcodesKey) ?? []
        return Set(arr)
    }

    private static func saveCountedBarcodes(_ set: Set<String>) {
        UserDefaults.standard.set(Array(set), forKey: countedBarcodesKey)
    }
}
