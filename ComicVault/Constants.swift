//
//  Constants.swift
//  ComicVault
//
//  File created on 10/15/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Central app-wide constants (keys, URLs, limits, copy strings).
//

import Foundation

enum Constants {
    /// A short, plain-English note clarifying that values shown are estimates.
    static let valueDisclaimer =
    """
    Values shown here are estimates based on available guide/pricing data.
    They are not a guarantee of sale price. Condition, market demand, and
    other factors can significantly impact real-world value.
    """
}

// Convenience top-level alias used by existing views like Add/Edit/Detail.
let ValueDisclaimer = Constants.valueDisclaimer
