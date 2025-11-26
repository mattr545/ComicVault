//
//  ValueHistory.swift
//  ComicVault
//
//  File created on 10/15/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Backwards-compatibility shim; real types live in ValuePoint.swift.
//
//  Running Edit Log
//  - 10-28-25: Converted to shim to avoid duplicate models.
//  - 11-08-25: Header normalization.
//
//
//  NOTE
//  This file is now a compatibility shim. The canonical value-history
//  models (ValuePoint, ValueSource) live in `ValuePoint.swift`.
//  We keep this file so existing imports continue to compile without
//  introducing duplicate type definitions.
//

import Foundation

// Intentionally left without type declarations.
// Use `ValuePoint` and `ValueSource` from `ValuePoint.swift`.
