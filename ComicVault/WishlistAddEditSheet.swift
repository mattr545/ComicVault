//
//  WishlistAddEditSheet.swift
//  ComicVault
//
//  File created on 10/16/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Add/edit form sheet for individual wishlist entries.
//
//  Running Edit Log
//  - 10-19-25: Clarified comments and behavior.
//  - 11-08-25: Header normalization.
//
//

import SwiftUI

struct WishlistAddEditSheet: View {
    var initial: Comic?

    /// onSave: title, issue, publisher, notes, barcode, targetPrice
    var onSave: (_ title: String,
                 _ issue: Int?,
                 _ publisher: String?,
                 _ notes: String?,
                 _ barcode: String?,
                 _ targetPrice: Double?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var issueNumber: String
    @State private var publisher: String
    @State private var notes: String
    @State private var barcode: String
    @State private var targetPriceText: String

    init(
        initial: Comic? = nil,
        onSave: @escaping (_ title: String,
                           _ issue: Int?,
                           _ publisher: String?,
                           _ notes: String?,
                           _ barcode: String?,
                           _ targetPrice: Double?) -> Void
    ) {
        self.initial = initial
        self.onSave  = onSave

        _title          = State(initialValue: initial?.title ?? "")
        _issueNumber    = State(initialValue: initial?.issueNumber.map(String.init) ?? "")
        _publisher      = State(initialValue: initial?.publisher ?? "")
        _notes          = State(initialValue: initial?.notes ?? "")
        _barcode        = State(initialValue: initial?.barcode ?? "")
        _targetPriceText = State(
            initialValue: initial?.wishlistTargetPrice
                .map { String(format: "%.2f", $0) } ?? ""
        )
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)

                    HStack {
                        TextField("Issue #", text: $issueNumber)
                            .keyboardType(.numberPad)
                        TextField("Publisher", text: $publisher)
                    }

                    TextField("Barcode (optional)", text: $barcode)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }

                Section("Target Price (optional)") {
                    TextField("Notify me at or below… (USD)", text: $targetPriceText)
                        .keyboardType(.decimalPad)
                    Text("Used for wishlist alerts when enabled in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Notes") {
                    TextField("Notes…", text: $notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
            }
            .navigationTitle(initial == nil ? "Add to Wishlist" : "Edit Wishlist Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let i = Int(issueNumber.trimmingCharacters(in: .whitespaces))
        let p = publisher.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = barcode.trimmingCharacters(in: .whitespacesAndNewlines)

        let target: Double?
        let trimmedTarget = targetPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTarget.isEmpty {
            target = nil
        } else {
            target = Double(trimmedTarget)
        }

        onSave(
            t,
            i,
            p.isEmpty ? nil : p,
            n.isEmpty ? nil : n,
            b.isEmpty ? nil : b,
            target
        )
        dismiss()
    }
}
