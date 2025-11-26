//
//  EditComicView.swift
//  ComicVault
//
//  File created on 10/19/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Form for editing existing comic metadata, storage, and notes.
//

import SwiftUI
import UIKit

struct EditComicView: View {

    let comic: Comic
    let onSave: (Comic) -> Void

    @Environment(\.dismiss) private var dismiss

    // Base fields mirrored into local state
    @State private var title: String
    @State private var issueNumberText: String
    @State private var publisher: String
    @State private var coverImage: UIImage?
    @State private var grade: String
    @State private var notes: String
    @State private var barcode: String

    // Value preview / controls
    @State private var manualValueText: String
    @State private var working = false
    @State private var currentValue: Double?
    @State private var lastEstimatedAt: Date?

    // Gate: AI Assist availability
    private var aiAssistEnabled: Bool {
        UserDefaults.standard.bool(forKey: "ai.enabled") && AIClient.shared.isConfigured
    }

    // Init from the incoming comic
    init(comic: Comic, onSave: @escaping (Comic) -> Void) {
        self.comic = comic
        self.onSave = onSave

        _title           = State(initialValue: comic.title)
        _issueNumberText = State(initialValue: comic.issueNumber.map(String.init) ?? "")
        _publisher       = State(initialValue: comic.publisher ?? "")
        _notes           = State(initialValue: comic.notes ?? "")
        _barcode         = State(initialValue: comic.barcode ?? "")
        _grade           = State(initialValue: comic.grade ?? "")

        _currentValue    = State(initialValue: comic.currentValue)
        _manualValueText = State(initialValue: comic.currentValue.map { String(format: "%.2f", $0) } ?? "")

        if let data = comic.imageData, let ui = UIImage(data: data) {
            _coverImage = State(initialValue: ui)
        } else {
            _coverImage = State(initialValue: nil)
        }
    }

    var body: some View {
        Form {
            // Cover (optional – UI only, not changing image here)
            Section("Cover (optional)") {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .foregroundColor(.secondary)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text("Choose Cover")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }

            // Details
            Section("Details") {
                TextField("Title", text: $title)

                HStack {
                    TextField("Issue #", text: $issueNumberText)
                        .keyboardType(.numberPad)
                    TextField("Publisher", text: $publisher)
                }

                TextField("Barcode", text: $barcode)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                TextField("Grade", text: $grade)

                // Notes (iOS 16+)
                notesField()
            }

            // AI Assist (gated)
            if aiAssistEnabled {
                Section("AI Assist") {
                    AIAssistPanel(
                        context: .addEdit(
                            title: title,
                            issue: Int(issueNumberText.trimmingCharacters(in: .whitespacesAndNewlines)),
                            publisher: publisher.isEmpty ? nil : publisher,
                            barcode: barcode.isEmpty ? nil : barcode,
                            notes: notes.isEmpty ? nil : notes
                        ),
                        onApply: { s in
                            if let v = s.title { title = v }
                            if let v = s.issueNumber { issueNumberText = String(v) }
                            if let v = s.publisher { publisher = v }
                            if let v = s.barcode { barcode = v }
                            if let v = s.notes { notes = v }
                            Haptics.success()
                        }
                    )
                }
            }

            // Value (manual + estimate hook)
            Section("Value") {
                HStack {
                    Text("Current Value")
                    Spacer()
                    Text(currentValueText)
                        .font(.headline)
                }

                if let last = lastEstimatedAt {
                    Text("Last checked: \(relativeDate(last))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    TextField("Manual value (USD)", text: $manualValueText)
                        .keyboardType(.decimalPad)
                    Button("Apply") { applyManual() }
                        .disabled(Double(manualValueText) == nil || Double(manualValueText)! < 0)
                }

                Button {
                    Task { await estimateNow() }
                } label: {
                    if working {
                        ProgressView()
                    } else {
                        Label("Estimate Value", systemImage: "chart.line.uptrend.xyaxis")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(working || title.trimmed().isEmpty)

                Text("Values shown here are estimates and not guarantees of sale price. Condition, market demand, and other factors can significantly impact real-world value.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .navigationTitle("Edit Comic")
        .navigationBarTitleDisplayMode(.inline)
        // Use legacy bar-items API to force plain text buttons (prevents pill + truncation)
        .navigationBarItems(
            leading:
                Button("Cancel") { dismiss() }
                    .font(.body)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false),
            trailing:
                Button("Save") { save() }
                    .font(.body)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .disabled(title.trimmed().isEmpty)
        )
    }

    // MARK: - Notes field (iOS 16+; no availability branching, removes warning)

    @ViewBuilder
    private func notesField() -> some View {
        TextField("Notes", text: $notes, axis: .vertical)
            .lineLimit(3, reservesSpace: true)
    }

    // MARK: - Actions

    private func applyManual() {
        guard let v = Double(manualValueText), v >= 0 else { return }
        currentValue = v
    }

    private func save() {
        let cleanTitle     = title.trimmed()
        let cleanIssue     = Int(issueNumberText.trimmingCharacters(in: .whitespaces))
        let cleanPublisher = publisher.trimmed().nilIfEmpty
        let cleanNotes     = notes.trimmed().nilIfEmpty
        let cleanBarcode   = barcode.trimmed().nilIfEmpty
        let cleanGrade     = grade.trimmed().nilIfEmpty
        let imageData      = coverImage?.jpegData(compressionQuality: 0.85)

        // Build an updated Comic, preserving any fields we didn’t expose here.
        let updated = Comic(
            id: comic.id,
            title: cleanTitle.isEmpty ? "Untitled" : cleanTitle,
            issueNumber: cleanIssue,
            publisher: cleanPublisher,
            imageData: imageData ?? comic.imageData,
            variant: comic.variant,
            grade: cleanGrade,
            currentValue: currentValue,
            barcode: cleanBarcode,
            notes: cleanNotes,
            createdAt: comic.createdAt,
            storageLocation: comic.storageLocation,     // unchanged
            volume: comic.volume,                        // unchanged
            year: comic.year,                            // unchanged
            keyFlags: comic.keyFlags,                    // unchanged
            firstAppearanceOf: comic.firstAppearanceOf,  // unchanged
            cameoOf: comic.cameoOf,                      // unchanged
            storylineTags: comic.storylineTags,          // unchanged
            variantNotes: comic.variantNotes,            // unchanged
            extraImages: comic.extraImages               // unchanged
        )

        onSave(updated)
        dismiss()
    }

    private func estimateNow() async {
        working = true
        defer { working = false }

        // Use a minimal comic snapshot for the estimator.
        let temp = Comic(
            id: comic.id,
            title: title.trimmed().isEmpty ? "Untitled" : title.trimmed(),
            issueNumber: Int(issueNumberText.trimmingCharacters(in: .whitespaces)),
            publisher: publisher.trimmed().nilIfEmpty,
            imageData: comic.imageData,
            variant: comic.variant,
            grade: grade.trimmed().nilIfEmpty,
            currentValue: currentValue,
            barcode: barcode.trimmed().nilIfEmpty,
            notes: notes.trimmed().nilIfEmpty,
            createdAt: comic.createdAt,
            storageLocation: comic.storageLocation,
            volume: comic.volume,
            year: comic.year,
            keyFlags: comic.keyFlags,
            firstAppearanceOf: comic.firstAppearanceOf,
            cameoOf: comic.cameoOf,
            storylineTags: comic.storylineTags,
            variantNotes: comic.variantNotes,
            extraImages: comic.extraImages
        )

        let result = await PriceService.estimateValue(for: temp)
        currentValue    = result.updatedComic.currentValue
        lastEstimatedAt = result.quote?.obtainedAt
    }

    // MARK: - Helpers

    private var currentValueText: String {
        if let v = currentValue {
            return v.formatted(.currency(code: "USD"))
        } else {
            return "—"
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .short
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Tiny string helpers

private extension String {
    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? {
        let t = trimmed()
        return t.isEmpty ? nil : t
    }
}
