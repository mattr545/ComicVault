//
//  AIAssistPanel.swift
//  ComicVault
//
//  File created on 10/29/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Inline AI assistant panel for context-aware suggestions inside ComicVault.
//
//

import SwiftUI

struct AIAssistPanel: View {

    // MARK: - Types

    enum Context: Equatable {
        case addEdit(title: String?, issue: Int?, publisher: String?, barcode: String?, notes: String?)
    }

    struct Suggestion: Equatable {
        var title: String?
        var issueNumber: Int?
        var publisher: String?
        var barcode: String?
        var notes: String?
        var keyFlags: [String] = []
    }

    // MARK: - Inputs

    let context: Context
    let onApply: (Suggestion) -> Void

    // MARK: - State

    @State private var suggestion: Suggestion?
    @State private var isLoading = false
    @State private var applied = false
    @State private var whyText: String?
    @State private var explaining = false

    // Debounce task (latest wins)
    @State private var debounceTask: Task<Void, Never>?

    private var aiEnabled: Bool {
        UserDefaults.standard.bool(forKey: "ai.enabled") && AIClient.shared.isConfigured
    }

    // MARK: - UI

    var body: some View {
        Form {
            Section("Suggestion") {
                if isLoading && suggestion == nil {
                    HStack {
                        ProgressView()
                        Text("Thinking…").foregroundStyle(.secondary)
                    }
                } else if let s = suggestion {
                    VStack(alignment: .leading, spacing: 8) {
                        fieldRow(label: "Title", value: s.title)
                        fieldRow(label: "Issue #", value: s.issueNumber.map(String.init))
                        fieldRow(label: "Publisher", value: s.publisher)
                        fieldRow(label: "Barcode", value: s.barcode)

                        if let n = s.notes, !n.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notes").font(.subheadline.weight(.semibold))
                                Text(n).foregroundStyle(.secondary)
                            }
                        }

                        if !s.keyFlags.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AI Flags").font(.subheadline.weight(.semibold))
                                Text(s.keyFlags.joined(separator: ", "))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if aiEnabled {
                            Button {
                                Task { await explainNow() }
                            } label: {
                                if explaining {
                                    HStack {
                                        ProgressView()
                                        Text("Why?")
                                    }
                                } else {
                                    Label("Why?", systemImage: "questionmark.circle")
                                }
                            }
                            .buttonStyle(.bordered)

                            if let why = whyText, !why.isEmpty {
                                Text(why)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                    }
                } else {
                    Text(aiEnabled ? "No suggestion yet." : "AI Assist is off or not configured.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    if let s = suggestion {
                        onApply(s)
                        applied = true
                    }
                } label: {
                    Label("Apply to Fields", systemImage: "square.and.arrow.down")
                }
                .disabled(suggestion == nil)
            } footer: {
                if applied {
                    Text("Applied. You can review and save from the previous screen.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            Task { await buildInitialSuggestion() }
        }
        // Use compat shim to avoid iOS 17 deprecation while keeping semantics.
        .onChangeCompat(of: context) { _ in
            debouncedRecompute()
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func fieldRow(label: String, value: String?) -> some View {
        HStack {
            Text(label).font(.subheadline.weight(.semibold))
            Spacer()
            Text(value ?? "—").foregroundStyle(.secondary)
        }
    }

    private func makeParts() -> (title: String, issue: Int?, publisher: String?, notes: String?, barcode: String?) {
        switch context {
        case let .addEdit(title, issue, publisher, barcode, notes):
            let t = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return (
                t,
                issue,
                publisher?.trimmingCharacters(in: .whitespacesAndNewlines),
                notes?.trimmingCharacters(in: .whitespacesAndNewlines),
                barcode?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    private func map(_ s: AISuggestedFields, issue: Int?, barcode: String?) -> Suggestion {
        Suggestion(
            title: s.title,
            issueNumber: issue,
            publisher: s.publisher,
            barcode: barcode,
            notes: s.storageNote,
            keyFlags: s.keyFlags ?? []
        )
    }

    private func debouncedRecompute() {
        debounceTask?.cancel()
        whyText = nil
        explaining = false
        isLoading = aiEnabled

        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // ~500ms
            if Task.isCancelled { return }
            await buildSuggestion()
        }
    }

    private func buildInitialSuggestion() async {
        guard aiEnabled else { return }
        isLoading = true
        defer { isLoading = false }
        await buildSuggestion()
    }

    private func buildSuggestion() async {
        guard aiEnabled else {
            suggestion = nil
            return
        }

        let parts = makeParts()
        guard !parts.title.isEmpty else {
            suggestion = nil
            return
        }

        if let fields = await AISuggester.suggest(
            title: parts.title,
            issue: parts.issue,
            publisher: parts.publisher,
            notes: parts.notes,
            barcode: parts.barcode
        ) {
            suggestion = map(fields, issue: parts.issue, barcode: parts.barcode)
        } else {
            suggestion = nil
        }
        isLoading = false
    }

    private func explainNow() async {
        guard aiEnabled, let sug = suggestion else { return }
        explaining = true
        whyText = nil
        defer { explaining = false }

        let parts = makeParts()

        if let text = await AISuggester.explainWhy(
            currentTitle: parts.title,
            currentIssue: parts.issue,
            currentPublisher: parts.publisher,
            notes: parts.notes,
            barcode: parts.barcode,
            suggestion: AISuggestedFields(
                title: sug.title,
                publisher: sug.publisher,
                storageNote: sug.notes,
                keyFlags: sug.keyFlags
            )
        ) {
            whyText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
