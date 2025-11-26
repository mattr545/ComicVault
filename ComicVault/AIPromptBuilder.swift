//
//  AIPromptBuilder.swift
//  ComicVault
//
//  File created on 10/29/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Centralized prompt factory for AI-powered features.
//

import Foundation

enum AIPromptBuilder {
    static func buildPrompt(from draft: ComicDraft) -> String {
        var lines: [String] = []
        lines.append("Known comic info:")
        if !draft.title.isEmpty { lines.append("Title: \(draft.title)") }
        if let issue = draft.issueNumber { lines.append("Issue: \(issue)") }
        if let pub = draft.publisher, !pub.isEmpty { lines.append("Publisher: \(pub)") }
        if let note = draft.notes, !note.isEmpty { lines.append("Notes: \(note)") }

        lines.append("")
        lines.append("Return JSON ONLY with keys: title, publisher, keyFlags (array of keywords).")

        return lines.joined(separator: "\n")
    }
}

/// Lightweight temporary representation of a comic being edited.
/// Used so AI Assist can observe the draft without touching main model.
struct ComicDraft: Equatable {
    var title: String = ""
    var issueNumber: Int?
    var publisher: String?
    var notes: String?
}
