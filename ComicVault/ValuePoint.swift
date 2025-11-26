//
//  ValuePoint.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Represents a single timestamped valuation for a comic.
//
//  Canonical value-history types used app-wide.
//  Only keep THIS file for ValuePoint/ValueSource declarations.
//

import Foundation

/// Where a value point came from.
public enum ValueSource: String, Codable, Equatable {
    case manual       // user-entered
    case estimated    // from PriceService / lookup
}

/// A single point in time for a comic’s value history.
public struct ValuePoint: Codable, Equatable, Identifiable {
    public let id: UUID
    public let date: Date
    public let value: Double
    public let source: ValueSource
    public let note: String?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        value: Double,
        source: ValueSource,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.value = value
        self.source = source
        self.note = note
    }
}

// MARK: - Lightweight conveniences (non-breaking)

/// Many call sites accidentally use a lowercase factory (e.g., `valuePoint(value: 42, source: .manual)`).
/// Provide it so those references compile without changing any calling code.
@inline(__always)
public func valuePoint(
    value: Double,
    source: ValueSource,
    date: Date = Date(),
    id: UUID = UUID(),
    note: String? = nil
) -> ValuePoint {
    ValuePoint(id: id, date: date, value: value, source: source, note: note)
}

/// Optional alias used by some views/services.
public typealias ValueHistory = [ValuePoint]
