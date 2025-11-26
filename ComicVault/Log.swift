//
//  Log.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Lightweight logging utilities used across the app.
//

import os

enum Log {
    private static let logger = Logger(subsystem: "com.comicvault.app", category: "app")

    static func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    static func sensitive(_ message: String) {
        // Redacted by default in unified logging; still visible on-device with special tools.
        logger.debug("\(message, privacy: .private)")
    }
}
