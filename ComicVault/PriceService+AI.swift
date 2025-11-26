//
//  PriceService+AI.swift
//  ComicVault
//
//  File created on 11/03/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Optional AI-based estimator wrapper over PriceService.
//
//  Running Edit Log
//  - 11-03-25: Added AI estimator shim and parsing.
//  - 11-08-25: Header normalization.
//
//

import Foundation

extension PriceService {

    /// Tries to get an AI estimate. If AI isn’t configured or parsing fails,
    /// falls back to `estimateValue(for:)`.
    static func estimateValueAI(for comic: Comic) async -> EstimateResult {
        // 1) If no AI config, use the local estimator.
        guard AIClient.shared.isConfigured else {
            return await estimateValue(for: comic)
        }

        // 2) Build a short, constrained prompt and ask the model.
        let title = comic.title
        let issue = comic.issueNumber.map { "#\($0)" } ?? ""
        let pub   = comic.publisher ?? ""
        let cover = comic.coverPrice != nil
            ? String(format: "$%.2f", comic.coverPrice!)
            : "unknown"

        let prompt = """
        You are a comic book price assistant. Respond with a single number only.
        Estimate a conservative RAW value in USD (no $ sign, no text, just digits with optional decimal).
        Title: \(title) \(issue)
        Publisher: \(pub)
        Cover price: \(cover)
        If unsure, return a cautious but reasonable number.
        """

        do {
            let text = try await AIClient.shared.complete(prompt: prompt, maxTokens: 12)
            // Parse first number (e.g., "125.50" from any response)
            if let number = Self.firstNumber(in: text) {
                var updated = comic
                updated.currentValue = max(updated.currentValue ?? 0, number)
                let q = ValueQuote(obtainedAt: Date(), source: "AI Estimator")
                return EstimateResult(updatedComic: updated, quote: q)
            } else {
                // Couldn’t parse → fall back
                return await estimateValue(for: comic)
            }
        } catch {
            // Any AI error → fall back
            return await estimateValue(for: comic)
        }
    }

    // MARK: - Helpers

    /// Extracts the first decimal number found in a string.
    private static func firstNumber(in text: String) -> Double? {
        // Match 123, 123.45, .45, 0.45 (we’ll normalize lone leading dot)
        let pattern = #"(?<!\d)(?:\d+\.?\d*|\.\d+)(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        var token = ns.substring(with: match.range)
        if token.hasPrefix(".") { token = "0" + token }
        return Double(token)
    }
}
