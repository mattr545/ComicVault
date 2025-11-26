//
//  AISuggester.swift
//  ComicVault
//
//  File created on 10/29/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Lightweight suggestion engine to propose related comics and tags.
//

import Foundation

struct AISuggestedFields: Codable, Equatable {
    var title: String?
    var publisher: String?
    var storageNote: String?
    var keyFlags: [String]?
}

enum AISuggester {
    /// Ask the configured AI model for structured suggestions.
    static func suggest(
        title: String,
        issue: Int?,
        publisher: String?,
        notes: String?,
        barcode: String?
    ) async -> AISuggestedFields? {
        guard AIClient.shared.isConfigured else { return nil }

        let contract = """
        Return ONLY strict minified JSON object with keys:
        {"title":string|null,"publisher":string|null,"storageNote":string|null,"keyFlags":[string]|null}
        Do not include prose or code fences. If unknown, use null. keyFlags examples:
        ["First Appearance","Origin","Cameo","Iconic Cover","Variant","Low Print Run"].
        """

        // Build a compact context map (drop empties)
        var parts: [String: Any] = ["title": title]
        if let issue { parts["issue"] = issue }
        if let publisher, !publisher.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts["publisher"] = publisher }
        if let notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts["notes"] = notes }
        if let barcode, !barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts["barcode"] = barcode }

        let prompt = """
        You are embedded in a comics cataloging app.
        \(contract)
        Context:\n\(parts)
        """

        do {
            let raw = try await AIClient.shared.complete(prompt: prompt, maxTokens: 250)

            // Try decoding direct JSON first
            if let data = raw.data(using: .utf8),
               let parsed = try? JSONDecoder().decode(AISuggestedFields.self, from: data) {
                return parsed
            }

            // If the model returned extra text, pull the first {...} block defensively
            if let r = raw.range(of: #"\{.*\}"#, options: .regularExpression) {
                let obj = String(raw[r])
                if let data = obj.data(using: .utf8),
                   let parsed = try? JSONDecoder().decode(AISuggestedFields.self, from: data) {
                    return parsed
                }
            }
        } catch {
            // fall through to nil
        }
        return nil
    }

    /// One short paragraph explaining the suggestion.
    static func explainWhy(
        currentTitle: String,
        currentIssue: Int?,
        currentPublisher: String?,
        notes: String?,
        barcode: String?,
        suggestion: AISuggestedFields
    ) async -> String? {
        guard AIClient.shared.isConfigured else { return nil }

        let expl = """
        Explain in <=80 words why these suggestions make sense. Reference any signals lightly (title tokens, barcode patterns, notes).
        Current: {title:\(currentTitle), issue:\(currentIssue?.description ?? "nil"), publisher:\(currentPublisher ?? "nil"), notes:\(notes ?? "nil"), barcode:\(barcode ?? "nil")}
        Suggested: \(suggestion)
        """

        return try? await AIClient.shared.complete(prompt: expl, maxTokens: 120)
    }
}
