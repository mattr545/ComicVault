//
//  BenchmarkService.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Micro benchmarking helpers to profile key ComicVault operations.
//

import Foundation

/// Result of comparing one comic against the median of its peers.
struct BenchmarkResult {
    /// Median of latest known values among peers.
    let median: Double
    /// Difference between the comic’s current value and the median.
    let delta: Double           // comic.currentValue - median
    /// Percentage over/under the median (nil when median == 0).
    let pct: Double?
}

/// Extremely simple local benchmark:
///  - Finds "peers" by matching Title + IssueNumber (and Publisher when present)
///  - Computes median of their *latest* known values (from ValuePoint history when present)
///  - Returns delta/pct against the median
///
/// Note: intentionally offline and lightweight. You can swap to a real market source later
/// without changing view code.
enum BenchmarkService {

    static func medianFor(
        _ comic: Comic,
        in comics: [Comic],
        historyProvider: (UUID) -> [ValuePoint]   // <- latest ValuePoint model
    ) -> BenchmarkResult? {

        // 1) Peer filter
        let peers = comics.filter { other in
            guard other.id != comic.id else { return false }
            guard other.title.caseInsensitiveCompare(comic.title) == .orderedSame else { return false }
            if let i1 = comic.issueNumber, let i2 = other.issueNumber, i1 != i2 { return false }
            if let p1 = comic.publisher, let p2 = other.publisher,
               !p1.isEmpty, !p2.isEmpty, p1.caseInsensitiveCompare(p2) != .orderedSame {
                return false
            }
            return true
        }

        // 2) Latest known value per peer (prefer history; fall back to currentValue)
        var peerValues: [Double] = peers.compactMap { p in
            let hist = historyProvider(p.id)
            if let last = hist.sorted(by: { $0.date < $1.date }).last?.value {
                return last
            }
            return p.currentValue
        }
        .compactMap { $0 }
        .filter { $0 > 0 }

        guard !peerValues.isEmpty else { return nil }

        // 3) Median
        peerValues.sort()
        let mid = peerValues.count / 2
        let median: Double = (peerValues.count % 2 == 0)
            ? (peerValues[mid - 1] + peerValues[mid]) / 2.0
            : peerValues[mid]

        // 4) Compare
        let current = comic.currentValue ?? 0
        let delta = current - median
        let pct: Double? = median > 0 ? (delta / median) * 100.0 : nil

        return BenchmarkResult(median: median, delta: delta, pct: pct)
    }
}
