//  ComicVineClient.swift
//  ComicVault
//
//  File created on 10/18/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Minimal ComicVine HTTP client for metadata lookup.
//

import Foundation

final class ComicVineClient {
    static let shared = ComicVineClient()

    private let base = URL(string: "https://comicvine.gamespot.com/api/")!

    private init() {}

    // Prefer user key from Settings; fall back to embedded key (can be blank).
    private var activeAPIKey: String {
        let override = UserDefaults.standard.string(forKey: "settings.comicVineAPIKey") ?? ""
        return override.isEmpty ? ComicVineConfig.embeddedAPIKey : override
    }

    // MARK: - Public

    /// Search by barcode/UPC/ISBN
    func searchByBarcode(_ upc: String) async throws -> MetadataSuggestion? {
        let trimmed = upc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Try issues first
        let issueHits = try await search(resourceTypes: ["issue"], query: trimmed, limit: 5)
        if let best = issueHits.first { return best }

        // Then try matching volumes
        let vols = try await search(resourceTypes: ["volume"], query: trimmed, limit: 5)
        return vols.first
    }

    /// Title search (optionally bias toward a specific issue number)
    func searchByTitle(_ title: String, issue: Int?) async throws -> [MetadataSuggestion] {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return [] }

        var suggestions = try await search(resourceTypes: ["issue"], query: t, limit: 12)

        // If caller provided an issue number, prefer close matches.
        if let n = issue {
            suggestions.sort { a, b in
                let am = (a.issueNumber ?? -1) == n
                let bm = (b.issueNumber ?? -1) == n
                if am != bm { return am }     // prefer exact issue-number match
                return false
            }
        }

        // If nothing from issues, try volumes for a coarse match.
        if suggestions.isEmpty {
            let vols = try await search(resourceTypes: ["volume"], query: t, limit: 8)
            suggestions.append(contentsOf: vols)
        }

        // Deduplicate by (title|issue|publisher)
        var seen = Set<String>()
        return suggestions.filter {
            let key = "\($0.title.lowercased())|\($0.issueNumber ?? -1)|\($0.publisher ?? "")"
            if seen.contains(key) { return false }
            seen.insert(key); return true
        }
    }

    // MARK: - Internal

    private func search(resourceTypes: [String], query: String, limit: Int) async throws -> [MetadataSuggestion] {
        // If no key at all, short-circuit cleanly.
        guard !activeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        var comps = URLComponents(url: base.appendingPathComponent("search/"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "api_key", value: activeAPIKey),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "resources", value: resourceTypes.joined(separator: ",")),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = comps.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(ComicVineSearch.self, from: data)
        return decoded.results.compactMap { $0.toSuggestion() }
    }
}

// MARK: - DTOs

private struct ComicVineSearch: Decodable {
    let results: [ComicVineResult]
}

private struct ComicVineImage: Decodable {
    let small_url: String?
    let thumb_url: String?
    let medium_url: String?
    let original_url: String?
}

private struct ComicVineResult: Decodable {
    let name: String?
    let deck: String?
    let description: String?
    let site_detail_url: String?
    let resource_type: String?
    let image: ComicVineImage?
    let issue_number: String?
    let volume: VolumeRef?
    let publisher: PublisherRef?
    let cover_date: String?   // "YYYY-MM-DD" on issues when available

    struct VolumeRef: Decodable {
        let name: String?
        let publisher: PublisherRef?
    }
    struct PublisherRef: Decodable {
        let name: String?
    }

    func toSuggestion() -> MetadataSuggestion? {
        let titleText: String? = {
            switch resource_type?.lowercased() {
            case "issue":  return volume?.name ?? name
            case "volume": return name
            default:       return name
            }
        }()

        guard let title = titleText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return nil }

        let issueInt: Int? = {
            guard let s = issue_number?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
            let digits = s.filter("0123456789".contains)
            return Int(digits)
        }()

        let pub: String? = publisher?.name ?? volume?.publisher?.name

        let firstImageURLString = image?.medium_url ?? image?.small_url ?? image?.thumb_url ?? image?.original_url
        let url = firstImageURLString.flatMap(URL.init(string:))

        return MetadataSuggestion(
            title: title,
            issueNumber: issueInt,
            publisher: pub,
            description: deck ?? description,
            coverImageURL: url,
            barcode: nil,
            coverDate: cover_date
        )
    }
}
