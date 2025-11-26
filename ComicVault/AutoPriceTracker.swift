//
//  AutoPriceTracker.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Legacy helper for scheduling automatic price checks; superseded by PriceService.runAutoUpdateIfNeeded.
//
//  Running Edit Log
//  - 11-08-25: Updated to respect main-actor isolation when marking last auto-run.
//
//
//  Runs automatic price updates on a schedule using PriceService.
//  - Respects PriceService.autoFrequency & shouldRunAutoUpdate.
//  - Uses PriceService.batchEstimate(for:).
//  - Writes .estimated ValuePoints via CollectionViewModel.addValuePoint(...).
//  - Lets PriceAlertManager handle notifications.
//

import Foundation

enum AutoPriceTracker {

    /// Call this from app lifecycle (e.g., when app becomes active).
    /// Kept for compatibility; new code should use PriceService.runAutoUpdateIfNeeded(on:).
    static func runIfNeeded(using vm: CollectionViewModel) {
        guard PriceService.shouldRunAutoUpdate() else { return }

        Task.detached(priority: .utility) {
            // Snapshot comics on main actor
            let comics: [Comic] = await MainActor.run { vm.comics }
            guard !comics.isEmpty else { return }

            let estimates = await PriceService.batchEstimate(for: comics)
            guard !estimates.isEmpty else { return }

            await MainActor.run {
                for (id, result) in estimates {
                    guard let newValue = result.updatedComic.currentValue else { continue }
                    // quote.source (e.g., "CSV Import" / "Local Estimator") is stored for traceability.
                    vm.addValuePoint(
                        for: id,
                        value: newValue,
                        source: .estimated,
                        note: result.quote?.source
                    )
                }
            }

            // Mark last auto-run on the main actor to satisfy isolation rules.
            await MainActor.run {
                PriceService.markAutoRun()
            }
        }
    }
}
