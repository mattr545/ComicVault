//
//  ComicVineAPIKey.swift
//  ComicVault
//
//  File created on 10/18/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Persistence helpers for storing and retrieving the ComicVine API key.
//
//  Pull API key from Keychain (no secrets in source).
//

import Foundation

enum ComicVineAPIKey {
    private static let service = "com.comicvault.apikeys"
    private static let account = "comicvine"

    /// Returns the current API key (if set), otherwise nil.
    static func current() -> String? {
        (try? SecureStore.get(service: service, account: account)) ?? nil
    }

    /// One-time setter from a user input/secure provisioning flow.
    static func set(_ key: String) throws {
        try SecureStore.set(key, service: service, account: account)
    }

    /// Clear the stored key (e.g., when user logs out).
    static func clear() {
        _ = SecureStore.remove(service: service, account: account)
    }
}
