//
//  AIPrompts.swift
//  ComicVault
//
//  File created on 10/29/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Static prompt templates used by AIClient and related helpers.
//

import Foundation

/// Describes every type of AI task the app supports.
/// Each task returns a ready-to-send system + user message pair.
enum AIPrompts {

    // MARK: - Add/Edit Assist

    /// Suggests title, publisher, issue, and key flags from partial user input.
    static func suggestComicInfo(title: String?, publisher: String?, notes: String?, barcode: String?) -> (system: String, user: String) {
        let sys = """
        You are an assistant that helps comic collectors fill out metadata.
        Return concise suggestions in plain English, no JSON or code.
        """
        var u = "Known fields:\n"
        if let t = title, !t.isEmpty { u += "Title: \(t)\n" }
        if let p = publisher, !p.isEmpty { u += "Publisher: \(p)\n" }
        if let n = notes, !n.isEmpty { u += "Notes: \(n)\n" }
        if let b = barcode, !b.isEmpty { u += "Barcode: \(b)\n" }
        u += "\nSuggest the most likely missing fields (title, publisher, key issue flags)."
        return (sys, u)
    }

    // MARK: - Price Estimation

    static func estimateValue(for comic: Comic) -> (system: String, user: String) {
        let sys = "You estimate comic book market values using recent sales and general knowledge."
        var u = "Estimate current fair-market value (USD) for the following comic.\n"
        u += "Title: \(comic.title)\n"
        if let i = comic.issueNumber { u += "Issue: \(i)\n" }
        if let p = comic.publisher { u += "Publisher: \(p)\n" }
        if let v = comic.variant { u += "Variant: \(v)\n" }
        if let g = comic.grade { u += "Grade: \(g)\n" }
        if let n = comic.notes { u += "Notes: \(n)\n" }
        u += "\nReturn a short answer like “≈ $25 (typical raw copy)”"
        return (sys, u)
    }

    // MARK: - Trend Explanation

    static func explainTrends(points: [TrendPoint]) -> (system: String, user: String) {
        let sys = "You summarize short financial trends clearly for comic collectors."
        let recent = points.suffix(5).map { "(\($0.date.formatted(date: .abbreviated, time: .omitted)), $\(Int($0.value)))" }.joined(separator: ", ")
        let u = "Explain the trend represented by these total-value points: \(recent). Keep it under 3 sentences."
        return (sys, u)
    }

    // MARK: - Data Cleaning

    static func normalizePublisherList(_ names: [String]) -> (system: String, user: String) {
        let sys = "You clean and unify comic publisher names, returning canonical forms."
        let joined = names.joined(separator: ", ")
        let u = "Normalize these publisher names to their standard form: \(joined)."
        return (sys, u)
    }

    // MARK: - Wishlist Hints

    static func relatedIssues(from titles: [String]) -> (system: String, user: String) {
        let sys = "You suggest related comic issues or series collectors might want."
        let joined = titles.joined(separator: ", ")
        let u = "Suggest 3–5 related or key issues similar to: \(joined). Include short reasons."
        return (sys, u)
    }

    // MARK: - Help / FAQ

    static func helpAnswer(for question: String) -> (system: String, user: String) {
        let sys = """
        You are the ComicVault in-app helper.  
        Use this manual summary: Add/Edit to track comics, Portfolio for value charts, Wishlist to save wants, Settings for backups and AI.  
        Keep answers brief (1–3 sentences).
        """
        let u = "User asked: \(question)"
        return (sys, u)
    }
}
