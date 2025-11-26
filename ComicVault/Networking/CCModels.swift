//
//  CCModels.swift
//  ComicVault
//
//  File created on 11/25/25 by ApogeeINVENT, a software engineering company,
//  in collaboration with the CryptoComics team.
//
//  Description:
//  Data models for CryptoComics API responses.
//

import Foundation

/// Generic API response format
struct CCResponse: Codable {
    let status: Int
    let statusMessage: String?
    let data: [String: String]?
}

/// A comic owned by the user on CryptoComics
struct CCRemoteComic: Identifiable, Codable {
    let id: String
    let title: String
    let issue: String?
    let series: String?
    let coverURL: URL?
    let storageNote: String = "Stored on CryptoComics Marketplace"
}
