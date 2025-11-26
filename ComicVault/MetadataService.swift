//
//  MetadataService.swift
//  ComicVault
//
//  File created on 10/18/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Service that orchestrates metadata lookups, OCR title detection, and caching.
//
//  Running Edit Log
//  - 10/18/25: Initial implementation with ComicVineClient support.
//  - 11/08/25: Added OCR fallback + text normalization.
//  - 11/09/25: Confirmed async Vision pipeline; tightened regex normalization; removed redundant catches; zero warnings.
//  - 11/09/25 (Cover OCR v2): Added token clustering + nearest numeric detection for issue parsing; completed Task D “Vision upgrades for scan flow”.
//  - 11/10/25: Fixed Substring/String mismatch in OCR v2 cluster lookup to resolve build error.
//

import Foundation
import UIKit
import Vision

private enum MetadataConfig {
    static var enabled: Bool {
        UserDefaults.standard.bool(forKey: "settings.metadataLookup")
    }
}

enum MetadataService {

    // MARK: - Public API

    static func lookupByBarcode(_ code: String) async -> MetadataSuggestion? {
        if let demo = demoByBarcode(code) { return demo }
        guard MetadataConfig.enabled else { return nil }

        if let cached = MetadataQuota.cachedSuggestion(for: code) { return cached }

        if let live = try? await ComicVineClient.shared.searchByBarcode(code) {
            return live
        }
        return nil
    }

    static func lookupByTitle(_ title: String, issue: Int? = nil) async -> [MetadataSuggestion] {
        let demos = demoByTitle(title, issue: issue)
        if !demos.isEmpty { return demos }

        guard MetadataConfig.enabled else { return [] }

        if let live = try? await ComicVineClient.shared.searchByTitle(title, issue: issue) {
            return live
        }
        return []
    }

    // MARK: - OCR helpers

    static func detectBarcode(in image: UIImage) async -> String? {
        guard let cg = image.cgImage else { return nil }
        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try handler.perform([request])
            guard let result = request.results?.first as? VNBarcodeObservation else { return nil }
            return result.payloadStringValue?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "")
        } catch {
            return nil
        }
    }

    static func ocrSuggest(from image: UIImage) async -> MetadataSuggestion? {
        guard let text = await recognizeText(in: image) else { return nil }
        let (query, issue) = pickLikelyTitleQueryAndIssue(from: text)
        guard !query.isEmpty else { return nil }
        let list = await lookupByTitle(query, issue: issue)
        return list.first
    }

    // MARK: - Private OCR

    private static func recognizeText(in image: UIImage) async -> String? {
        guard let cg = image.cgImage else { return nil }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try handler.perform([req])
            let strings = (req.results ?? []).flatMap { $0.topCandidates(1).map(\.string) }
            let text = strings.joined(separator: " ").lowercased()
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    // MARK: - OCR v2: Title + Issue detection

    /// Extracts the most likely comic title and issue number from recognized text.
    private static func pickLikelyTitleQueryAndIssue(from text: String) -> (String, Int?) {
        // Normalize to lowercase and strip non-alphanumerics except spaces and #
        let pattern = "[^a-z0-9#\\s]"
        let cleaned = text.lowercased().replacingOccurrences(of: pattern,
                                                             with: " ",
                                                             options: .regularExpression)

        let words = cleaned
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !words.isEmpty else { return ("", nil) }

        // Group consecutive non-numeric tokens into clusters
        var clusters: [String] = []
        var currentCluster: [String] = []

        for word in words {
            if word.rangeOfCharacter(from: .decimalDigits) == nil {
                currentCluster.append(word)
            } else if !currentCluster.isEmpty {
                clusters.append(currentCluster.joined(separator: " "))
                currentCluster.removeAll()
            }
        }
        if !currentCluster.isEmpty {
            clusters.append(currentCluster.joined(separator: " "))
        }

        // Pick the largest cluster as the most likely title
        let bestCluster = clusters.sorted { $0.count > $1.count }.first ?? ""
        if bestCluster.isEmpty { return ("", nil) }

        // Find the nearest numeric token to the first word of this cluster within +/- 5 tokens
        var issue: Int? = nil

        if let firstWordSub = bestCluster.split(separator: " ").first {
            let firstWord = String(firstWordSub)
            if let clusterIndex = words.firstIndex(of: firstWord) {
                let lower = max(0, clusterIndex - 5)
                let upper = min(words.count - 1, clusterIndex + 5)
                for i in lower...upper {
                    let token = words[i].replacingOccurrences(of: "#", with: "")
                    if let val = Int(token) {
                        issue = val
                        break
                    }
                }
            }
        }

        return (bestCluster, issue)
    }

    // MARK: - Demo data

    private static func demoByBarcode(_ code: String) -> MetadataSuggestion? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let table: [String: MetadataSuggestion] = [
            "76194134182800111": MetadataSuggestion(
                title: "Batman",
                issueNumber: 1,
                publisher: "DC Comics",
                description: "The Dark Knight returns in a new run.",
                coverImageURL: nil,
                barcode: trimmed,
                coverDate: "2016-06-01"
            ),
            "75960608956700111": MetadataSuggestion(
                title: "Amazing Spider-Man",
                issueNumber: 1,
                publisher: "Marvel",
                description: "A friendly neighborhood fresh start.",
                coverImageURL: nil,
                barcode: trimmed,
                coverDate: "2014-04-01"
            ),
            "9781302900533": MetadataSuggestion(
                title: "Ms. Marvel",
                issueNumber: 1,
                publisher: "Marvel",
                description: "Kamala Khan steps up.",
                coverImageURL: nil,
                barcode: trimmed,
                coverDate: "2016-10-01"
            )
        ]
        return table[trimmed]
    }

    private static func demoByTitle(_ title: String, issue: Int?) -> [MetadataSuggestion] {
        let t = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var results: [MetadataSuggestion] = []
        if t.contains("batman") {
            results.append(MetadataSuggestion(title: "Batman", issueNumber: issue ?? 1, publisher: "DC Comics", description: nil, coverImageURL: nil, barcode: nil, coverDate: nil))
            results.append(MetadataSuggestion(title: "Detective Comics", issueNumber: issue, publisher: "DC Comics", description: nil, coverImageURL: nil, barcode: nil, coverDate: nil))
        }
        if t.contains("spider") {
            results.append(MetadataSuggestion(title: "Amazing Spider-Man", issueNumber: issue ?? 1, publisher: "Marvel", description: nil, coverImageURL: nil, barcode: nil, coverDate: nil))
            results.append(MetadataSuggestion(title: "Spectacular Spider-Man", issueNumber: issue, publisher: "Marvel", description: nil, coverImageURL: nil, barcode: nil, coverDate: nil))
        }
        if t.contains("superman") {
            results.append(MetadataSuggestion(title: "Superman", issueNumber: issue ?? 1, publisher: "DC Comics", description: nil, coverImageURL: nil, barcode: nil, coverDate: nil))
        }
        return results
    }
}
