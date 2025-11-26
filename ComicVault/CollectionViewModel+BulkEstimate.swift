//
//  CollectionViewModel+BulkEstimate.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Async bulk estimation helpers using PriceService for subsets or all comics.
//
//  Running Edit Log
//  - 10-27-25: Initial bulk estimation APIs.
//  - 11-08-25: Header normalization.
//
//  Purpose
//  - Async bulk estimator for all (or some) comics.
//  - Uses PriceService.estimateValue / batchEstimate and appends `.estimated` ValuePoints
//    via CollectionViewModel.addValuePoint(...).
//  - Cancellation-safe, optional progress callback.
//  - Auto-tracker helper wired to PriceService scheduling.
//  - No UI assumptions; call from anywhere (e.g., app lifecycle).
//

import Foundation

extension CollectionViewModel {

    /// Re-computes local estimates for **all** comics and appends an `.estimated` value point
    /// when the estimator returns a number. Safe to call repeatedly.
    /// - Parameter onProgress: Optional callback `(done, total)` invoked after each item.
    func bulkEstimateAll(onProgress: ((Int, Int) -> Void)? = nil) async {
        let snapshot = comics
        let total = snapshot.count
        guard total > 0 else { return }

        // Prefer batch when available
        let results = await PriceService.batchEstimate(for: snapshot)

        var done = 0
        for comic in snapshot {
            if Task.isCancelled { break }

            if let result = results[comic.id],
               let v = result.updatedComic.currentValue {
                addValuePoint(for: comic.id, value: v, source: .estimated, note: nil)
            }

            done += 1
            onProgress?(done, total)
        }
    }

    /// Re-computes local estimates **only for the given IDs**.
    /// Useful for selection-based bulk actions.
    func bulkEstimate(forIDs ids: [UUID], onProgress: ((Int, Int) -> Void)? = nil) async {
        let idSet = Set(ids)
        let subset = comics.filter { idSet.contains($0.id) }
        let total = subset.count
        guard total > 0 else { return }

        let results = await PriceService.batchEstimate(for: subset)

        var done = 0
        for comic in subset {
            if Task.isCancelled { break }

            if let result = results[comic.id],
               let v = result.updatedComic.currentValue {
                addValuePoint(for: comic.id, value: v, source: .estimated, note: nil)
            }

            done += 1
            onProgress?(done, total)
        }
    }

    /// Auto price tracker:
    /// - Checks PriceService schedule.
    /// - If due, runs a batch estimate for the whole collection.
    /// - Writes `.estimated` ValuePoints via `addValuePoint`, including provider source in the note.
    /// - Safe to call from app launch / foreground; no-op if not due.
    @MainActor
    func runAutoPriceUpdateIfNeeded() async {
        guard PriceService.shouldRunAutoUpdate() else { return }

        let snapshot = comics
        guard !snapshot.isEmpty else {
            PriceService.markAutoRun() // avoid hammering on empty libs
            return
        }

        let results = await PriceService.batchEstimate(for: snapshot)
        guard !results.isEmpty else {
            PriceService.markAutoRun()
            return
        }

        for comic in snapshot {
            guard let result = results[comic.id],
                  let value = result.updatedComic.currentValue else { continue }

            // Include provider name (if any) in the note so history shows where it came from.
            let note = result.quote.map { "Auto: \($0.source)" }

            addValuePoint(
                for: comic.id,
                value: value,
                source: .estimated,
                note: note
            )
        }

        PriceService.markAutoRun()
    }
}
