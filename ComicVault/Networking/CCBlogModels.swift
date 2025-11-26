//
//  CCBlogModels.swift
//  ComicVault
//
//  File created on 11/25/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Lightweight models for the CryptoComics blog feed.
//

import Foundation

struct CCBlogPost: Identifiable, Decodable, Hashable {
    let id: UUID
    let title: String
    let summary: String
    let imageURL: URL?
    let category: String
    let publishedAt: Date
    let url: URL

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case imageURL = "image_url"
        case category
        case publishedAt = "published_at"
        case url
    }

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        imageURL: URL?,
        category: String,
        publishedAt: Date,
        url: URL
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.imageURL = imageURL
        self.category = category
        self.publishedAt = publishedAt
        self.url = url
    }
}
