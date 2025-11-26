//
//  MigrationManager.swift
//  ComicVault
//
//  File created on 10/16/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Handles data migrations between ComicVault schema versions.
//
//  Running Edit Log
//  - 10-19-25: Added v1 and v2 migrations.
//  - 10-22-25: Bumped to v3 for Project 1 fields. Backward compatible, so this migration is a no-op aside from version stamp.
//
//  NOTES
//  - Adding optional fields in Comic is backward compatible for JSON decoding.
//  - We still bump the version so future code can check for capabilities.
//

import Foundation

struct MigrationManager {

    // Versions:
    // 0 - legacy keys
    // 1 - unified "saved_comics"
    // 2 - wishlist rename and backup folder move
    // 3 - Project 1 valuation and photos additions
    static let currentVersion = 3
    private static let versionKey = "data_version"

    static func runMigrations() {
        let storedVersion = UserDefaults.standard.integer(forKey: versionKey)
        guard storedVersion < currentVersion else { return }

        if storedVersion == 0 {
            migrateFromV0toV1()
        }
        if storedVersion <= 1 {
            migrateFromV1toV2()
        }
        if storedVersion <= 2 {
            migrateFromV2toV3()
        }

        UserDefaults.standard.set(currentVersion, forKey: versionKey)
    }

    private static func migrateFromV0toV1() {
        let defaults = UserDefaults.standard
        if let old = defaults.data(forKey: "comics") {
            defaults.set(old, forKey: "saved_comics")
            defaults.removeObject(forKey: "comics")
        }
    }

    private static func migrateFromV1toV2() {
        let defaults = UserDefaults.standard
        if let oldWishlist = defaults.data(forKey: "wishlist_items") {
            defaults.set(oldWishlist, forKey: "saved_wishlist")
            defaults.removeObject(forKey: "wishlist_items")
        }

        let fm = FileManager.default
        guard let doc = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let oldBackup = doc.appendingPathComponent("ComicVaultBackups")
        let newBackup = doc.appendingPathComponent("Backups")
        if fm.fileExists(atPath: oldBackup.path) && !fm.fileExists(atPath: newBackup.path) {
            try? fm.moveItem(at: oldBackup, to: newBackup)
        }
    }

    private static func migrateFromV2toV3() {
        // No data transform needed. Optional fields in Comic decode fine.
        // This stamp makes it easy to gate new features if ever needed.
    }

    static func migrationStatus() -> String {
        let version = UserDefaults.standard.integer(forKey: versionKey)
        return "ComicVault data version: \(version)"
    }
}
