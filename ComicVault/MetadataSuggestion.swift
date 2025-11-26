//
//  MetadataSuggestion.swift
//  ComicVault
//
//  File created on 10/18/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Models and helpers for suggested metadata candidates.
//

import Foundation

struct MetadataSuggestion: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var issueNumber: Int?
    var publisher: String?
    var description: String?
    var coverImageURL: URL?
    var barcode: String?
    var coverDate: String?
}
