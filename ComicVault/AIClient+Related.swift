//
//  AIClient+Related.swift
//  ComicVault
//
//  File created on 10/29/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Convenience helpers on AIClient for “related titles” and other specialized prompts.
//
//

import Foundation

extension AIClient {
    /// Returns a few related series/issues based on the provided wishlist titles.
    /// If the OpenAI key isn't configured, or if the network call isn't implemented,
    /// we fall back to a tiny offline heuristic so the UI still works.
    func suggestRelated(from wishlistTitles: [String]) async throws -> [String] {
        // 1) If an API key appears present, you could call a real model here.
        //    For now, we still return a deterministic local result to keep the app building.
        if hasUserAPIKey {
            // Placeholder for a future real completion call. Keep deterministic output for now.
            return heuristicRelated(from: wishlistTitles)
        }

        // 2) No key configured → offline suggestions so the button isn’t dead.
        return heuristicRelated(from: wishlistTitles)
    }
}

// MARK: - Private helpers (local, deterministic)

private extension AIClient {
    var hasUserAPIKey: Bool {
        // Mirrors the key you use in Settings/Keychain:
        // service: "com.comicvault.ai.openai", account: "user_api_key"
        // If SecureStore isn't available or key isn't present, we treat as not configured.
        (try? SecureStore.get(service: "com.comicvault.ai.openai", account: "user_api_key"))?
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .isEmpty == false
    }

    func heuristicRelated(from titles: [String]) -> [String] {
        var out: [String] = []
        for raw in titles.prefix(5) {
            let t = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard !t.isEmpty else { continue }

            out.append("\(t) (Direct Edition)")
            out.append("\(t) (Newsstand)")

            // If there's an issue number pattern like "... #123"
            if let num = extractTrailingIssueNumber(from: t) {
                out.append(replacingTrailingIssue(in: t, with: num - 1))   // previous issue
                out.append(replacingTrailingIssue(in: t, with: num + 1))   // next issue
            } else {
                // Otherwise offer an Annual as a common related pick
                out.append("\(t) Annual #1")
            }
        }

        // Deduplicate while preserving order
        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }
    }

    func extractTrailingIssueNumber(from title: String) -> Int? {
        // Looks for a "#123" at the end (ignores trailing spaces)
        let trimmed = title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard let hash = trimmed.lastIndex(of: "#") else { return nil }
        let after = trimmed.index(after: hash)
        let tail = String(trimmed[after...])
        return Int(tail)
    }

    func replacingTrailingIssue(in title: String, with newNumber: Int) -> String {
        guard newNumber > 0 else { return title }
        let trimmed = title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard let hash = trimmed.lastIndex(of: "#") else { return "\(trimmed) #\(newNumber)" }
        let prefix = String(trimmed[..<hash])
        return "\(prefix)#\(newNumber)"
    }
}
