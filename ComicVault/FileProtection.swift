//
//  FileProtection.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Utilities to apply iOS file protection to sensitive on-disk data.
//

import Foundation

enum FileProtection {
    /// Applies iOS data protection and excludes the file from iCloud backups.
    static func harden(at url: URL) throws {
        try (url as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)

        do {
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
        } catch {
            // If the filesystem doesn’t support data protection (e.g., Simulator),
            // we silently ignore the attribute failure but keep the exclude-from-backup flag.
        }
    }
}
