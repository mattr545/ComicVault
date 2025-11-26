//
//  AITrendsHelper.swift
//  ComicVault
//
//  File created on 10/29/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Utilities for summarizing pricing and popularity trends using AI/locals.
//
//

import Foundation

enum AITrendsHelper {

    // MARK: Public APIs

    static func explainTrends(points: [TrendPoint]) async throws -> String {
        let pairs = points.sorted { $0.date < $1.date }.map { ($0.date, $0.value) }
        return try await summarize(pairs, label: "portfolio trend")
    }

    static func explainPortfolio(entries: [PortfolioEntry]) async throws -> String {
        let pairs = entries.sorted { $0.date < $1.date }.map { ($0.date, $0.total) }
        return try await summarize(pairs, label: "portfolio snapshots")
    }

    // MARK: Core

    private static func summarize(_ series: [(Date, Double)], label: String) async throws -> String {
        guard series.count >= 2 else { return "Not enough data to summarize \(label) yet." }

        // Basic stats
        let sorted = series.sorted { $0.0 < $1.0 }
        let startDate = sorted.first!.0
        let endDate   = sorted.last!.0
        let startVal  = sorted.first!.1
        let endVal    = sorted.last!.1
        let change    = endVal - startVal
        let pct       = startVal == 0 ? 0 : change / startVal
        let minPt     = sorted.min(by: { $0.1 < $1.1 })!
        let maxPt     = sorted.max(by: { $0.1 < $1.1 })!

        // Try AI if configured
        if AIClient.shared.isConfigured {
            let df = Self.df
            let rows = sorted.prefix(180)  // cap prompt size
                .map { "\(df.string(from: $0.0))=\(Self.currency($0.1))" }
                .joined(separator: ", ")

            let prompt = """
            You are summarizing a comic collection's value history for a friendly in-app blurb.
            Data points (\(label)) as date=value:
            \(rows)

            Start=\(df.string(from: startDate)) \(Self.currency(startVal));
            End=\(df.string(from: endDate)) \(Self.currency(endVal));
            Change=\(Self.currency(change)) (\(Self.percent(pct))).
            High=\(df.string(from: maxPt.0)) \(Self.currency(maxPt.1));
            Low=\(df.string(from: minPt.0)) \(Self.currency(minPt.1)).

            Write 2–4 short sentences, plain English, no bullets. Mention overall direction,
            the size of the move, and highlight the high/low dates. Keep it neutral and concise.
            """
            do {
                return try await AIClient.shared.complete(prompt: prompt, maxTokens: 200)
            } catch {
                // fall back to local summary
            }
        }

        // Local fallback (no network)
        let dir = change >= 0 ? "up" : "down"
        let df = Self.df
        return """
        From \(df.string(from: startDate)) to \(df.string(from: endDate)), your portfolio moved \(dir) by \(Self.currency(abs(change))) (\(Self.percent(abs(pct)))). The high was \(Self.currency(maxPt.1)) on \(df.string(from: maxPt.0)) and the low was \(Self.currency(minPt.1)) on \(df.string(from: minPt.0)). Current total: \(Self.currency(endVal)).
        """
    }

    // MARK: Formatting

    private static var df: DateFormatter = {
        let d = DateFormatter()
        d.dateStyle = .medium
        d.timeStyle = .none
        return d
    }()

    private static func currency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f.string(from: NSNumber(value: v)) ?? "$0.00"
    }

    private static func percent(_ p: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: p)) ?? "0%"
    }
}
