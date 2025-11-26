//
//  QuickAddView.swift
//  ComicVault
//
//  File created on 10/19/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Lightweight add form for rapid comic entry.
//

import SwiftUI

struct QuickAddView: View {

    @EnvironmentObject private var vm: CollectionViewModel
    @Environment(\.dismiss) private var dismiss

    // Local UI state
    @State private var title: String = ""
    @State private var issueNumber: String = ""
    @State private var publisher: String = ""
    @State private var barcode: String = ""
    @State private var notes: String = ""
    @State private var autoCloseAfterSave: Bool = true

    // Scan flow
    @State private var presentScanner = false
    @State private var presentReview  = false
    @State private var pendingSuggestion: MetadataSuggestion?
    @State private var alertMessage: String?

    // AI Assist
    @State private var showAIPanel = false

    // Gate: only show AI Assist when user enabled and key is present
    private var aiAssistEnabled: Bool {
        UserDefaults.standard.bool(forKey: "ai.enabled") && AIClient.shared.isConfigured
    }

    var body: some View {
        // Keep the container to match the previous structure,
        // but make it always use NavigationStack (iOS 16+).
        NavContainer {
            Form {
                // Details
                Section("Details") {
                    TextField("Title (required)", text: $title)
                        .textInputAutocapitalization(.words)

                    HStack {
                        TextField("Issue #", text: $issueNumber)
                            .keyboardType(.numberPad)
                        TextField("Publisher", text: $publisher)
                            .textInputAutocapitalization(.words)
                    }

                    // AI Assist button (gated)
                    if aiAssistEnabled {
                        Button {
                            showAIPanel = true
                        } label: {
                            Label("Ask AI for Suggestions", systemImage: "sparkles")
                        }
                    }
                }

                // Barcode + Scan
                Section("Barcode") {
                    TextField("Scan or type barcode (optional)", text: $barcode)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)

                    Button {
                        presentScanner = true
                    } label: {
                        Label("Scan Barcode", systemImage: "barcode.viewfinder")
                    }
                }

                // Notes (iOS 16+ multiline TextField)
                Section("Notes") {
                    TextField("Anything else… (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                // Preferences
                Section {
                    Toggle("Close after Save", isOn: $autoCloseAfterSave)
                } footer: {
                    Text("Turn this off to keep the form open for fast, repeated entries.")
                }
            }
            .navigationTitle("Quick Add")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { save() }) {
                        Text("Save").font(.headline)
                    }
                    .disabled(title.trimmed().isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                    }
                }
            }
            // Scanner sheet
            .sheet(isPresented: $presentScanner) {
                BarcodeScannerView { code in
                    Task { await handleScanned(code) }
                }
            }
            // Review sheet
            .sheet(isPresented: $presentReview) {
                if let s = pendingSuggestion {
                    NavContainer {
                        ReviewAddView(suggestion: s)
                            .environmentObject(vm)
                            .navigationTitle("Review")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
            // AI Assist Panel (gated)
            .sheet(isPresented: Binding(
                get: { aiAssistEnabled && showAIPanel },
                set: { newVal in showAIPanel = newVal }
            )) {
                NavContainer {
                    AIAssistPanel(
                        context: .addEdit(
                            title: title,
                            issue: Int(issueNumber.trimmingCharacters(in: .whitespacesAndNewlines)),
                            publisher: publisher.trimmed().nilIfEmpty,
                            barcode: barcode.trimmed().nilIfEmpty,
                            notes: notes.trimmed().nilIfEmpty
                        ),
                        onApply: { suggestion in
                            if let t = suggestion.title { self.title = t }
                            if let i = suggestion.issueNumber { self.issueNumber = String(i) }
                            if let p = suggestion.publisher { self.publisher = p }
                            if let b = suggestion.barcode { self.barcode = b }
                            if let n = suggestion.notes { self.notes = n }
                        }
                    )
                    .navigationTitle("AI Suggestions")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .alert("Heads up",
                   isPresented: Binding(get: { alertMessage != nil },
                                        set: { _ in alertMessage = nil })) {
                Button("OK", role: .cancel) { }
                Button("Open Settings") { }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    // MARK: - Save / Scan

    private func save() {
        let cleanTitle     = title.trimmed()
        let cleanIssue     = Int(issueNumber.trimmingCharacters(in: .whitespacesAndNewlines))
        let cleanPublisher = publisher.trimmed().nilIfEmpty
        let cleanBarcode   = barcode.trimmed().nilIfEmpty
        let cleanNotes     = notes.trimmed().nilIfEmpty

        vm.addComic(
            title: cleanTitle.isEmpty ? "Untitled" : cleanTitle,
            issueNumber: cleanIssue,
            publisher: cleanPublisher,
            imageData: nil,
            barcode: cleanBarcode,
            notes: cleanNotes
        )

        if autoCloseAfterSave {
            dismiss()
        } else {
            title = ""; issueNumber = ""; publisher = ""; barcode = ""; notes = ""
        }
    }

    private func handleScanned(_ code: String) async {
        barcode = code // show in the field

        guard UserDefaults.standard.bool(forKey: "settings.metadataLookup") else {
            alertMessage = "Online Metadata is turned off. You can enable it in Settings."
            return
        }

        if let cached = MetadataQuota.cachedSuggestion(for: code) {
            pendingSuggestion = cached
            presentReview = true
            return
        }

        if !MetadataQuota.alreadyCounted(barcode: code) && !MetadataQuota.canCountNewLookup() {
            alertMessage = "You have used the 10 free trial lookups. Add your free ComicVine key in Settings to continue."
            return
        }

        if let live = await MetadataService.lookupByBarcode(code) {
            MetadataQuota.cacheSuggestion(live, barcode: code)
            if !MetadataQuota.alreadyCounted(barcode: code) {
                MetadataQuota.recordSuccess(barcode: code)
            }
            pendingSuggestion = live
            presentReview = true
        } else {
            alertMessage = "No internet connection or no result found. You can still save manually."
        }
    }
}

// MARK: - Simple container (iOS 16+)

@ViewBuilder
private func NavContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    NavigationStack { content() }
}

// MARK: - Small helpers

private extension String {
    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? {
        let t = trimmed()
        return t.isEmpty ? nil : self
    }
}
