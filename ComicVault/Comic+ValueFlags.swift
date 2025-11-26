//
//  Comic+ValueFlags.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Temporary helper exposing isValueVerified as a computed flag.
//
//  Running Edit Log
//  - 10-22-25: Added heuristic isValueVerified shim.
//  - 11-08-25: Header normalization.
//
//

import Foundation

extension Comic {
    /// Temporary computed flag so UI compiles. We’ll add a real stored property later.
    var isValueVerified: Bool {
        // Heuristic fallback: if notes contain "[verified]" treat it as verified.
        // Otherwise return false. Safe default.
        return (notes?.localizedCaseInsensitiveContains("[verified]") ?? false)
    }
}

