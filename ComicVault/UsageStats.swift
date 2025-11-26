//
//  UsageStats.swift
//  ComicVault
//
//  Created by Matthew Russell on 11/09/25
//
//  Description: Local-only tracker for non-personal usage metrics.
//  Tracks feature engagement anonymously and stays fully on-device.
//
//  Running Edit Log
//  - 11-09-25: Added lightweight usage tracking (scanner launches, comics added, etc.)
//

import Foundation

enum UsageStats {

    /// Increments a counter for a given key
    static func increment(_ key: String) {
        let count = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(count + 1, forKey: key)
    }

    /// Retrieves a stored count
    static func get(_ key: String) -> Int {
        UserDefaults.standard.integer(forKey: key)
    }

    /// Resets a specific counter
    static func reset(_ key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Resets all known usage counters (if you ever add more keys)
    static func resetAll() {
        for key in allKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// List of all tracked keys for easy expansion
    private static let allKeys: [String] = [
        "scanner_launches",
        "comics_added",
        "wishlist_adds",
        "trends_viewed"
    ]
}
