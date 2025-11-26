//
//  PortfolioEntry.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Represents a dated portfolio total used by charts and snapshots.
//
//  Public data model used by Portfolio charts.
//  Keep this file simple and independent of SwiftUI.
//
//  Running Edit Log
//  - 11-10-25: Clarified Codable semantics so `id` is not persisted and is regenerated on decode.
//

import Foundation

public struct PortfolioEntry: Identifiable, Hashable, Codable {
    /// Unique ID for SwiftUI lists/charts; regenerated as needed.
    public var id: UUID

    /// The date of this portfolio snapshot.
    public let date: Date

    /// The total estimated collection value at that time.
    public let total: Double

    // MARK: - Init

    /// Primary initializer used by SnapshotManager or chart views.
    public init(id: UUID = UUID(), date: Date, total: Double) {
        self.id = id
        self.date = date
        self.total = total
    }

    // MARK: - Codable

    /// Only persist `date` and `total`. `id` is regenerated on decode.
    private enum CodingKeys: String, CodingKey {
        case date
        case total
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let date = try container.decode(Date.self, forKey: .date)
        let total = try container.decode(Double.self, forKey: .total)
        self.init(id: UUID(), date: date, total: total)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(total, forKey: .total)
    }
}
