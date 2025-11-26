//
//  AddComicView.swift
//  ComicVault
//
//  File created on 10/15/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Add-comic form used across devices; supports cover image, barcode, storage, notes,
//               and optional series/credits details.
//
//  Running Edit Log
//  - 11-03-25: iOS 15 compatibility; simplified dependencies.
//  - 11-09-25: Wired “Scan Barcode” button to BarcodeScannerView with simulator fallback.
//  - 11-09-25: Added UsageStats tracking for comics_added.
//  - 11-10-25: Added optional Volume/Year + detailed credits fields,
//              folded non-core fields into notes to keep AddComicVM API stable.
//
//

import SwiftUI
import UIKit

// MARK: - Protocol the real view model should conform to
// Conform your actual CollectionViewModel like:
// extension CollectionViewModel: AddComicVM {}
protocol AddComicVM: ObservableObject {
    func addComic(
        title: String,
        issueNumber: Int?,
        publisher: String?,
        imageData: Data?,
        barcode: String?,
        notes: String?
    )
}

// MARK: - View

struct AddComicView<VM: AddComicVM>: View {
    @EnvironmentObject private var vm: VM
    @Environment(\.dismiss) private var dismiss

    // Basic fields
    @State private var title: String = ""
    @State private var issueNumberText: String = ""
    @State private var publisher: String = ""
    @State private var barcode: String = ""
    @State private var notes: String = ""
    @State private var storage: String = ""        // placeholder text field for future storage feature
    @State private var coverImage: UIImage?

    // Series details (optional; persisted via notes for now)
    @State private var volumeText: String = ""
    @State private var yearText: String = ""

    // Credits (optional; all folded into notes block for now)
    @State private var writer: String = ""
    @State private var penciler: String = ""
    @State private var inker: String = ""
    @State private var colorist: String = ""
    @State private var letterer: String = ""
    @State private var editor: String = ""
    @State private var coverArtist: String = ""
    @State private var otherCredits: String = ""

    // Optional “verified” marker (UI only here; can be wired later)
    @State private var isVerified: Bool = false

    // Scanner
    @State private var presentScanner = false

    var body: some View {
        NavigationView {
            Form {

                // Cover
                Section("Cover (optional)") {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(width: 64, height: 64)
                            .overlay {
                                if let ui = coverImage {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button {
                            pickPhoto()
                        } label: {
                            Label("Choose Cover", systemImage: "photo.on.rectangle.angled")
                        }
                    }
                }

                // Core Details
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

                    Button {
                        #if canImport(UIKit)
                        Haptics.tap(weight: .medium)
                        #endif
                        presentScanner = true
                    } label: {
                        Label("Scan Barcode", systemImage: "barcode.viewfinder")
                    }

                    TextField("Storage Location (e.g. Longbox 3)", text: $storage)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("General Notes")
                            .font(.subheadline.weight(.semibold))
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2))
                            )
                    }
                    .padding(.vertical, 4)
                }

                // Series / publication metadata (optional)
                Section("Series & Publication (optional)") {
                    HStack {
                        TextField("Volume (e.g. 1, 2, 3)", text: $volumeText)
                            .keyboardType(.numberPad)
                        TextField("Year (e.g. 1963)", text: $yearText)
                            .keyboardType(.numberPad)
                    }
                    Text("Used to distinguish runs like “Avengers Vol. 1 #1” vs “Vol. 2 #1”. Will sync with metadata lookups later.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Credits (optional)
                Section("Credits (optional)") {
                    TextField("Writer", text: $writer)
                    TextField("Penciler", text: $penciler)
                    TextField("Inker", text: $inker)
                    TextField("Colorist", text: $colorist)
                    TextField("Letterer", text: $letterer)
                    TextField("Editor", text: $editor)
                    TextField("Cover Artist", text: $coverArtist)
                    TextField("Other credits / roles", text: $otherCredits)

                    Text("These credits are saved into this comic’s notes for now so nothing is lost. Future updates can map them to structured fields and ComicVine data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Flags / Extras
                Section("Flags") {
                    Toggle("Mark as verified", isOn: $isVerified)
                }
            }
            .navigationTitle("Add Comic")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // Scanner presentation:
            // - On device: full-screen camera via BarcodeScannerView
            // - On simulator: friendly text-entry fallback (MockScannerSheet)
            .fullScreenCover(isPresented: $presentScanner) {
                #if targetEnvironment(simulator)
                MockScannerSheet(code: $barcode)
                #else
                BarcodeScannerView { scanned in
                    barcode = scanned.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                #endif
            }
        }
    }

    // MARK: - Actions

    private func save() {
        let cleanTitle     = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanIssue     = Int(issueNumberText.trimmingCharacters(in: .whitespaces))
        let cleanPublisher = publisher.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let cleanBarcode   = barcode.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let imageData      = coverImage?.jpegData(compressionQuality: 0.85)

        // Combine freeform notes + structured extras into one safe notes blob.
        let baseNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        var extraLines: [String] = []

        if let vol = volumeText.nilIfEmpty {
            extraLines.append("Volume: \(vol)")
        }
        if let yr = yearText.nilIfEmpty {
            extraLines.append("Year: \(yr)")
        }

        if let w = writer.nilIfEmpty { extraLines.append("Writer: \(w)") }
        if let p = penciler.nilIfEmpty { extraLines.append("Penciler: \(p)") }
        if let i = inker.nilIfEmpty { extraLines.append("Inker: \(i)") }
        if let c = colorist.nilIfEmpty { extraLines.append("Colorist: \(c)") }
        if let l = letterer.nilIfEmpty { extraLines.append("Letterer: \(l)") }
        if let e = editor.nilIfEmpty { extraLines.append("Editor: \(e)") }
        if let ca = coverArtist.nilIfEmpty { extraLines.append("Cover Artist: \(ca)") }
        if let o = otherCredits.nilIfEmpty { extraLines.append("Other Credits: \(o)") }

        let creditsBlock = extraLines.isEmpty ? nil : extraLines.joined(separator: "\n")

        let combinedNotes: String? = {
            switch (baseNotes.nilIfEmpty, creditsBlock) {
            case (nil, nil):
                return nil
            case (let n?, nil):
                return n
            case (nil, let c?):
                return c
            case (let n?, let c?):
                return n + "\n\n" + c
            }
        }()

        vm.addComic(
            title: cleanTitle.isEmpty ? "Untitled" : cleanTitle,
            issueNumber: cleanIssue,
            publisher: cleanPublisher,
            imageData: imageData,
            barcode: cleanBarcode,
            notes: combinedNotes
        )

        // Existing analytics hook (assumes UsageStats is defined elsewhere in the project).
        UsageStats.increment("comics_added")

        #if canImport(UIKit)
        Haptics.success()
        #endif

        dismiss()
    }

    // Wire in PHPicker later if desired
    private func pickPhoto() {
        // Intentionally left as a stub to keep dependencies minimal.
    }
}

// MARK: - Local Mock Scanner (simulator / fallback)

private struct MockScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var code: String
    @State private var temp: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Enter or Paste a Barcode") {
                    TextField("012345678905", text: $temp)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Scan Barcode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        code = temp.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                    .disabled(temp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Small helper

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
