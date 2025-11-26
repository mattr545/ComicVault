//
//  CollectionViewModel+AI.swift
//  ComicVault
//
//  File created on 11/03/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: AI helper to apply suggestions onto Comic records.
//
//  Running Edit Log
//  - 11-03-25: Added applyAISuggestion helper.
//  - 11-08-25: Header normalization.
//
//

import Foundation

extension CollectionViewModel {
    /// Store AI-generated annotations (e.g., normalized title or flags) on a comic by id.
    /// This is optional sugar so other views don’t need to know VM internals.
    func applyAISuggestion(
        id: UUID,
        title: String? = nil,
        issueNumber: Int? = nil,
        publisher: String? = nil,
        barcode: String? = nil,
        notes: String? = nil
    ) {
        guard let idx = comics.firstIndex(where: { $0.id == id }) else { return }
        var updated = comics[idx]
        if let t = title { updated.title = t }
        if let i = issueNumber { updated.issueNumber = i }
        if let p = publisher { updated.publisher = p }
        if let b = barcode { updated.barcode = b }
        if let n = notes { updated.notes = (updated.notes ?? "").isEmpty ? n : updated.notes! + "\n" + n }
        comics[idx] = updated
    }
}
