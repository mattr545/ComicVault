//
//  PriceService+Display.swift
//  ComicVault
//
//  File created on 10/21/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Convenience formatting helpers for displaying provider/estimate info.
//
//  Running Edit Log
//  - 10-22-25: Removed unused AppCurrency type; format as USD for MVP.
//  - 10-22-25: Added tiny helpers to present values consistently in the UI.
//
//  NOTES
//  Keep the display logic tiny and dependency-free. When we add a user-selectable
//  currency later, we’ll swap the formatter here.
//

import Foundation

enum PriceDisplay {
    /// Returns something like "$12.00" (USD).
    static func currency(_ amount: Double?) -> String {
        guard let amount else { return "—" }
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "USD"
        return nf.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    /// Returns something like "~$45 (est.)" for estimates, italicized in UI at call sites.
    static func approx(_ amount: Double?) -> String {
        guard let amount else { return "—" }
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "USD"
        let core = nf.string(from: NSNumber(value: amount)) ?? "$0.00"
        return "~\(core) (est.)"
    }
}
