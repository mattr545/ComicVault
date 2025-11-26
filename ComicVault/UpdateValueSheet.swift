//
//  UpdateValueSheet.swift
//  ComicVault
//
//  File created on 10/15/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Modal sheet for adding ValuePoint entries with source and note.
//
//  Running Edit Log
//  - 10-22-25: Added segmented source picker and note field.
//  - 11-08-25: Header normalization.
//
//  NOTES
//  This modal collects a value, a source, and an optional note, then writes it via the VM.
//

import SwiftUI

struct UpdateValueSheet: View {
    /// The comic we are updating.
    let comicID: UUID

    /// ViewModel that owns comics and value histories.
    @EnvironmentObject private var vm: CollectionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var valueText: String = ""
    @State private var source: ValueSource = .manual
    @State private var note: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Value") {
                    TextField("Amount (USD)", text: $valueText)
                        .keyboardType(.decimalPad)
                }

                Section("Source") {
                    Picker("Type", selection: $source) {
                        Text("Manual").tag(ValueSource.manual)
                        Text("Estimate").tag(ValueSource.estimated)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Note (optional)") {
                    TextField("Short note (e.g., graded at 9.8, auction comp)", text: $note)
                }
            }
            .navigationTitle("Update Value")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(parsedValue == nil)
                }
            }
        }
    }

    private var parsedValue: Double? {
        Double(valueText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func label(for s: ValueSource) -> String {
        switch s {
        case .manual:    return "Manual"
        case .estimated: return "Estimate"
        }
    }

    private func save() {
        guard let amount = parsedValue else { return }
        vm.addValuePoint(
            for: comicID,
            value: amount,
            source: source,
            note: note.isEmpty ? nil : note
        )
        dismiss()
    }
}
