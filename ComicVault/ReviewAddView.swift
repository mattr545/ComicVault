//
//  ReviewAddView.swift
//  ComicVault
//
//  File created on 10/19/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Review step when adding comics in bulk or via import.
//

import SwiftUI

struct ReviewAddView: View {
    @EnvironmentObject private var vm: CollectionViewModel
    @Environment(\.dismiss) private var dismiss

    // Prefill inputs
    let suggestion: MetadataSuggestion

    // Editable copies
    @State private var title: String
    @State private var issueText: String
    @State private var publisher: String
    @State private var barcode: String
    @State private var notes: String

    // AI Assist
    @State private var showAIPanel = false

    init(suggestion: MetadataSuggestion) {
        self.suggestion = suggestion
        _title     = State(initialValue: suggestion.title)
        _issueText = State(initialValue: suggestion.issueNumber.map(String.init) ?? "")
        _publisher = State(initialValue: suggestion.publisher ?? "")
        _barcode   = State(initialValue: suggestion.barcode ?? "")
        _notes     = State(initialValue: suggestion.description ?? "")
    }

    var body: some View {
        Form {
            // Cover preview if present
            if let url = suggestion.coverImageURL {
                Section("Cover Preview") {
                    HStack {
                        Spacer()
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.black.opacity(0.06)))
                        } placeholder: {
                            ProgressView()
                        }
                        Spacer()
                    }
                }
            }

            Section("Details") {
                TextField("Title", text: $title)
                HStack {
                    TextField("Issue #", text: $issueText)
                        .keyboardType(.numberPad)
                    TextField("Publisher", text: $publisher)
                }
                TextField("Barcode (optional)", text: $barcode)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                Button {
                    showAIPanel = true
                } label: {
                    Label("Ask AI for Suggestions", systemImage: "wand.and.stars")
                }
            }

            // iOS 15-friendly multiline notes
            Section("Notes") {
                VStack(alignment: .leading, spacing: 6) {
                    // Optional visible label for older OSes
                    Text("Notes")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)

                    TextEditor(text: $notes)
                        .frame(minHeight: 90)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2))
                        )
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("Review & Save")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .sheet(isPresented: $showAIPanel) {
            NavigationView {
                AIAssistPanel(
                    context: .addEdit(
                        title: title,
                        issue: Int(issueText.trimmingCharacters(in: .whitespaces)),
                        publisher: publisher.nilIfEmpty,
                        barcode: barcode.nilIfEmpty,
                        notes: notes.nilIfEmpty
                    ),
                    onApply: { s in
                        if let t = s.title { self.title = t }
                        if let i = s.issueNumber { self.issueText = String(i) }
                        if let p = s.publisher { self.publisher = p }
                        if let b = s.barcode { self.barcode = b }
                        if let n = s.notes { self.notes = n }
                    }
                )
                .navigationTitle("AI Suggestions")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanIssue = Int(issueText.trimmingCharacters(in: .whitespaces))
        let cleanPub   = publisher.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let cleanCode  = barcode.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        vm.addComic(
            title: cleanTitle.isEmpty ? "Untitled" : cleanTitle,
            issueNumber: cleanIssue,
            publisher: cleanPub,
            imageData: nil,
            barcode: cleanCode,
            notes: cleanNotes
        )
        dismiss()
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
