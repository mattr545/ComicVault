//
//  ComicVineConfig.swift
//  ComicVault
//
//  File created on 10/18/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Constants and configuration related to ComicVine integration.
//
//  Running Edit Log
//  - 10-22-25: Added embedded developer key container for 10-lookup trial.
//
//  NOTES
//  This file stores the embedded ComicVine developer key used for the on-device trial
//  (up to 10 unique barcode lookups per device). Users are encouraged to add their own
//  free key in Settings for unlimited lookups.
//

import Foundation

enum ComicVineConfig {
    /// Embedded developer key used for the trial. Keep private.
    static let embeddedAPIKey = "5ce2dcc29b1f5cef57054c110b8e5c26571ac67c"
}
