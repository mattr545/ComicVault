//
//  DefectPhoto.swift
//  ComicVault
//
//  File created on 11/08/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Model representing a user-captured photo of a specific comic defect.
//

import Foundation

struct DefectPhoto: Identifiable, Codable, Equatable {
    var id: UUID
    var data: Data
    var label: String?

    init(id: UUID = UUID(), data: Data, label: String? = nil) {
        self.id = id
        self.data = data
        self.label = label
    }
}

