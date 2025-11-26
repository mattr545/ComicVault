//
//  WishlistViewModel.swift
//  ComicVault
//
//  File created on 10/16/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Source of truth for wishlist comics with persistence and helpers.
//
//  Running Edit Log
//  - 10-19-25: Simplified CRUD + UserDefaults storage.
//  - 11-07-25: Added target price + watchlist-related keys.
//  - 11-08-25: Header normalization.
//
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class WishlistViewModel: ObservableObject {

    // MARK: - Settings keys (shared with Settings & views)

    static let autoEstimatesKey = "wishlist.auto.estimates.enabled"
    static let targetAlertsKey  = "wishlist.target.alerts.enabled"

    // MARK: - Public, observable state

    @Published var items: [Comic] = [] {
        didSet { save() }
    }

    // MARK: - Private storage

    private let saveKey = "wishlist_items_v1"

    // MARK: - Init

    init() {
        load()
    }

    // MARK: - CRUD

    func add(
        title: String,
        issue: Int?,
        publisher: String?,
        notes: String?,
        barcode: String?,
        targetPrice: Double? = nil
    ) {
        let cleanedTitle     = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedPublisher = publisher?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNotes     = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedBarcode   = barcode?.trimmingCharacters(in: .whitespacesAndNewlines)

        let new = Comic(
            title: cleanedTitle.isEmpty ? "Untitled" : cleanedTitle,
            issueNumber: issue,
            publisher: cleanedPublisher?.isEmpty == true ? nil : cleanedPublisher,
            imageData: nil,
            variant: nil,
            grade: nil,
            coverPrice: nil,
            currentValue: nil,
            lastValueUpdate: nil,
            barcode: cleanedBarcode?.isEmpty == true ? nil : cleanedBarcode,
            notes: cleanedNotes?.isEmpty == true ? nil : cleanedNotes,
            createdAt: Date(),
            storageLocation: nil,
            volume: nil,
            year: nil,
            keyFlags: nil,
            firstAppearanceOf: nil,
            cameoOf: nil,
            storylineTags: nil,
            variantNotes: nil,
            extraImages: nil,
            wishlistTargetPrice: targetPrice,
            modifiedAt: Date()
        )

        items.append(new)
    }

    func update(
        id: UUID,
        title: String,
        issue: Int?,
        publisher: String?,
        notes: String?,
        barcode: String?,
        targetPrice: Double?
    ) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }

        var updated = items[idx]

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.title       = trimmedTitle.isEmpty ? "Untitled" : trimmedTitle
        updated.issueNumber = issue

        let p = publisher?.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.publisher   = (p?.isEmpty == true) ? nil : p

        let n = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.notes       = (n?.isEmpty == true) ? nil : n

        let b = barcode?.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.barcode     = (b?.isEmpty == true) ? nil : b

        updated.wishlistTargetPrice = targetPrice

        updated.modifiedAt = Date()
        items[idx] = updated
    }

    func delete(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: saveKey)
        } catch {
            print("Failed to encode wishlist: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([Comic].self, from: data)
            items = decoded
        } catch {
            print("Failed to decode wishlist: \(error)")
            items = []
        }
    }

    // MARK: - Convenience

    var totalWishCount: Int { items.count }

    // MARK: - Auto price + target alerts

    /// Called from app lifecycle (e.g., on launch / foreground).
    /// Respects the wishlist auto-estimates + target-alert toggles.
    func refreshEstimatesIfNeeded() {
        let autoOn = UserDefaults.standard.bool(forKey: Self.autoEstimatesKey)
        guard autoOn, !items.isEmpty else { return }

        let snapshot = items

        Task(priority: .utility) {
            let map = await PriceService.batchEstimate(for: snapshot)
            guard !map.isEmpty else { return }

            await MainActor.run {
                var updated = self.items
                guard !updated.isEmpty else { return }

                let alertsOn = UserDefaults.standard.bool(forKey: Self.targetAlertsKey)

                for idx in updated.indices {
                    let id = updated[idx].id
                    guard let res = map[id],
                          let newValue = res.updatedComic.currentValue
                    else { continue }

                    let oldValue = updated[idx].currentValue
                    updated[idx].currentValue = newValue
                    updated[idx].lastValueUpdate = res.quote?.obtainedAt ?? Date()
                    updated[idx].modifiedAt = Date()

                    if alertsOn,
                       let target = updated[idx].wishlistTargetPrice,
                       newValue <= target,
                       #available(iOS 16.0, *)
                    {
                        PriceAlertManager.shared.checkAndNotify(
                            comic: updated[idx],
                            old: oldValue,
                            new: newValue,
                            provider: res.quote?.source
                        )
                    }
                }

                self.items = updated
            }
        }
    }
}

// MARK: - Non-breaking conveniences

extension WishlistViewModel {
    func add(
        title: String,
        issueNumber: Int?,
        publisher: String?,
        notes: String?,
        barcode: String?
    ) {
        add(title: title,
            issue: issueNumber,
            publisher: publisher,
            notes: notes,
            barcode: barcode,
            targetPrice: nil)
    }

    func update(
        id: UUID,
        title: String,
        issueNumber: Int?,
        publisher: String?,
        notes: String?,
        barcode: String?
    ) {
        update(id: id,
               title: title,
               issue: issueNumber,
               publisher: publisher,
               notes: notes,
               barcode: barcode,
               targetPrice: items.first(where: { $0.id == id })?.wishlistTargetPrice)
    }
}

// MARK: - Backward name compatibility

typealias WishListViewModel = WishlistViewModel
typealias WishlistManager  = WishlistViewModel
