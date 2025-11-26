//
//  PriceService.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Pluggable price router with Local provider, grade-aware hooks, and auto-update scheduler.
//
//  Running Edit Log
//  - 11-07-25: Introduced PriceProvider protocol + autoFrequency.
//  - 11-08-25: Added runAutoUpdateIfNeeded, grade-aware hooks, and header normalization.
//  - 11-08-25: Fixed provider unwrap in estimateValue(for:) to avoid optional binding error.
//
//

import Foundation

// MARK: - Shared types

struct ValueQuote: Codable, Equatable {
    let obtainedAt: Date
    let source: String        // e.g. "Local Estimator", "CSV Import", "GoCollect"
}

struct EstimateResult {
    let updatedComic: Comic
    let quote: ValueQuote?
}

// Grade range value hint (used with GradeSuggestion).
// Also defined in GradingModels.swift.
typealias GradeValueRangeAlias = GradeValueRange

// MARK: - Provider protocol

/// Any concrete pricing source (local, CSV, GoCollect, eBay, etc.) conforms here.
protocol PriceProvider {
    /// Internal identifier (e.g., "local", "csv", "gocollect").
    var id: String { get }

    /// Human-readable name (used in UI and ValueQuote.source).
    var displayName: String { get }

    /// Return a quote for a single comic or `nil` if this provider has no opinion.
    func quote(for comic: Comic) async throws -> EstimateResult?

    /// Optional batch quoting; default loops over `quote(for:)`.
    func batchQuote(for comics: [Comic]) async throws -> [UUID: EstimateResult]
}

extension PriceProvider {
    func batchQuote(for comics: [Comic]) async throws -> [UUID: EstimateResult] {
        var out: [UUID: EstimateResult] = [:]
        for comic in comics {
            if let res = try await quote(for: comic) {
                out[comic.id] = res
            }
        }
        return out
    }
}

/// Optional protocol for providers that can offer grade floor/ceiling ranges.
protocol GradeAwarePriceProvider: PriceProvider {
    func gradeRange(
        for comic: Comic,
        suggestion: GradeSuggestion
    ) async throws -> GradeValueRange
}

// MARK: - Central router

enum PriceService {

    // MARK: Auto-update scheduling

    enum AutoFrequency: String, CaseIterable, Identifiable {
        case off
        case daily
        case weekly

        var id: String { rawValue }

        var label: String {
            switch self {
            case .off:    return "Off"
            case .daily:  return "Daily"
            case .weekly: return "Weekly"
            }
        }

        var interval: TimeInterval? {
            switch self {
            case .off:    return nil
            case .daily:  return 60 * 60 * 24
            case .weekly: return 60 * 60 * 24 * 7
            }
        }
    }

    static let freqKey      = "price.auto.frequency"
    private static let lastRunKey = "price.auto.lastRun"

    static var autoFrequency: AutoFrequency {
        get {
            let raw = UserDefaults.standard.string(forKey: freqKey) ?? AutoFrequency.weekly.rawValue
            return AutoFrequency(rawValue: raw) ?? .weekly
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: freqKey)
        }
    }

    static var lastAutoRun: Date? {
        let ts = UserDefaults.standard.double(forKey: lastRunKey)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    static func shouldRunAutoUpdate(now: Date = Date()) -> Bool {
        guard let interval = autoFrequency.interval else { return false }
        guard let last = lastAutoRun else { return true }
        return now.timeIntervalSince(last) >= interval
    }

    static func markAutoRun(date: Date = Date()) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: lastRunKey)
    }

    // MARK: Provider wiring

    /// Current provider (swappable later without touching UI).
    private static var provider: PriceProvider = LocalCoverPriceProvider()

    // MARK: - Public API

    /// Single-comic estimation used across the app.
    static func estimateValue(for comic: Comic) async -> EstimateResult {
        // Try active provider first; ignore provider errors and fall back safely.
        do {
            if let res = try await provider.quote(for: comic) {
                return res
            }
        } catch {
            // Intentionally swallow; we'll use the local fallback below.
        }

        // Fallback: original 10× cover price behavior.
        var updated = comic
        if let cover = comic.coverPrice, cover > 0 {
            updated.currentValue = max(updated.currentValue ?? 0, cover * 10.0)
        }
        let quote = ValueQuote(obtainedAt: Date(), source: "Local Estimator")
        return EstimateResult(updatedComic: updated, quote: quote)
    }

    /// Batch estimation for multiple comics.
    static func batchEstimate(for comics: [Comic]) async -> [UUID: EstimateResult] {
        guard !comics.isEmpty else { return [:] }

        if let map = try? await provider.batchQuote(for: comics), !map.isEmpty {
            return map
        }

        var out: [UUID: EstimateResult] = [:]
        for comic in comics {
            let res = await estimateValue(for: comic)
            out[comic.id] = res
        }
        return out
    }

    // MARK: - Grade-aware value hint

    /// Returns a value hint floor/ceiling for a given grading suggestion.
    /// If the provider is grade-aware, delegate; otherwise use a single estimate for both.
    static func estimateRange(
        for comic: Comic,
        suggestion: GradeSuggestion
    ) async -> GradeValueRange {
        if let gp = provider as? GradeAwarePriceProvider,
           let range = try? await gp.gradeRange(for: comic, suggestion: suggestion) {
            return range
        }

        let base   = await estimateValue(for: comic)
        let value  = base.updatedComic.currentValue
        let source = base.quote?.source ?? "Local Estimator"
        return GradeValueRange(floor: value, ceiling: value, source: source)
    }

    // MARK: - Auto tracker for owned collection

    @MainActor
    static func runAutoUpdateIfNeeded(on collectionVM: CollectionViewModel) {
        guard shouldRunAutoUpdate() else { return }

        let comicsSnapshot = collectionVM.comics
        guard !comicsSnapshot.isEmpty else {
            markAutoRun()
            return
        }

        Task(priority: .utility) {
            let map = await batchEstimate(for: comicsSnapshot)
            guard !map.isEmpty else {
                await MainActor.run { markAutoRun() }
                return
            }

            await MainActor.run {
                for (id, result) in map {
                    if let value = result.updatedComic.currentValue {
                        let note = result.quote?.source
                        collectionVM.addValuePoint(
                            for: id,
                            value: value,
                            source: .estimated,
                            note: note
                        )
                    }
                }
                markAutoRun()
            }
        }
    }
}

// MARK: - Built-in free provider

private struct LocalCoverPriceProvider: PriceProvider {
    let id = "local"
    let displayName = "Local Estimator"

    func quote(for comic: Comic) async throws -> EstimateResult? {
        guard let cover = comic.coverPrice, cover > 0 else {
            return nil
        }

        var updated = comic
        let estimate = max(updated.currentValue ?? 0, cover * 10.0)
        updated.currentValue = estimate

        let quote = ValueQuote(obtainedAt: Date(), source: displayName)
        return EstimateResult(updatedComic: updated, quote: quote)
    }
}

// Grade-aware shim for the local provider (uses same value for floor/ceiling).
extension LocalCoverPriceProvider: GradeAwarePriceProvider {
    func gradeRange(
        for comic: Comic,
        suggestion: GradeSuggestion
    ) async throws -> GradeValueRange {
        if let res = try await quote(for: comic),
           let value = res.updatedComic.currentValue {
            return GradeValueRange(floor: value, ceiling: value, source: displayName)
        }
        return GradeValueRange(floor: nil, ceiling: nil, source: displayName)
    }
}
