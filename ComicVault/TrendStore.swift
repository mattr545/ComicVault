//
//  TrendStore.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Caches and exposes trend data for portfolio and markets.
//

import Foundation

/// One aggregated portfolio point (sum across all comics for a given day).
public struct TrendPoint: Identifiable, Equatable {
    public let id = UUID()
    public let date: Date
    public let value: Double
}

enum TrendStore {

    /// Build a portfolio series by day, summing each comic's last-known value at/before that day.
    /// - Parameters:
    ///   - comics: All comics in memory
    ///   - valueHistoryProvider: callback to get [ValuePoint] for a comic.id
    /// - Returns: Sorted daily series
    static func collectionSeries(
        comics: [Comic],
        valueHistoryProvider: (UUID) -> [ValuePoint]
    ) -> [TrendPoint] {

        // 1) Gather all unique dates from value histories (day-granularity)
        var daySet = Set<Date>()
        var perComicHist: [UUID: [ValuePoint]] = [:]

        let cal = Calendar.current

        for c in comics {
            let hist = valueHistoryProvider(c.id).sorted { $0.date < $1.date }
            perComicHist[c.id] = hist
            for p in hist {
                let day = cal.startOfDay(for: p.date)
                daySet.insert(day)
            }
        }

        guard !daySet.isEmpty else { return [] }
        let days = daySet.sorted()

        // 2) For each day, sum last known value per comic at/before that day
        var out: [TrendPoint] = []
        for day in days {
            var total: Double = 0
            for c in comics {
                if let hist = perComicHist[c.id], !hist.isEmpty {
                    // last point <= day
                    if let lastIdx = hist.lastIndex(where: { cal.startOfDay(for: $0.date) <= day }) {
                        total += hist[lastIdx].value
                    } else {
                        // if comic has a currentValue but no historical <= day, ignore (no value yet that day)
                    }
                } else if let v = c.currentValue {
                    // no history but currentValue exists → treat as value today only
                    if cal.isDate(cal.startOfDay(for: Date()), inSameDayAs: day) {
                        total += v
                    }
                }
            }
            out.append(TrendPoint(date: day, value: total))
        }

        return out.sorted { $0.date < $1.date }
    }
}
