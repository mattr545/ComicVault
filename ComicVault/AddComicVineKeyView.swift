//
//  AddComicVineKeyView.swift
//  ComicVault
//
//  File created on 10/18/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Settings subview that captures and validates the ComicVine API key.
//
//
//
//

import SwiftUI

private let kUserAPIKey = "settings.comicVineAPIKey"

struct AddComicVineKeyView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey: String = UserDefaults.standard.string(forKey: kUserAPIKey) ?? ""
    @State private var showSavedBanner = false

    var body: some View {
        Form {
            Section("ComicVine API") {
                Text("Enter your personal ComicVine API key. If left blank, the app will use the embedded trial key with limited lookups.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("Paste API Key", text: $apiKey, prompt: Text("e.g. 5ce2dc…"))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.body.monospaced())

                Button("Save Key") {
                    let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    UserDefaults.standard.set(trimmed, forKey: kUserAPIKey)
                    showSavedBanner = true
                    Haptics.success()
                }
                .buttonStyle(.borderedProminent)

                if showSavedBanner {
                    Text("Saved. The app will use this key for future lookups.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Where to get a key") {
                Link(
                    "Create a free key on ComicVine",
                    destination: URL(string: "https://comicvine.gamespot.com/api/")!
                )
            }
        }
        .navigationTitle("ComicVine Key")
        .navigationBarTitleDisplayMode(.inline)
        .cvGroupedFormStyle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }
}

// Use grouped form style only when available (iOS 16+).
// Renamed to avoid duplicate symbol collisions across files.
fileprivate extension View {
    @ViewBuilder
    func cvGroupedFormStyle() -> some View {
        if #available(iOS 16, *) {
            self.formStyle(.grouped)
        } else {
            self
        }
    }
}

// Use NavigationView here so preview also works on iOS 15 targets.
#Preview {
    NavigationView { AddComicVineKeyView() }
}
