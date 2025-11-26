//
//  ComicVineKeyHelpView.swift
//  ComicVault
//
//  File created on 10/18/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Help view explaining how to obtain and enter a ComicVine API key.
//

import SwiftUI


// === STRUCT: ComicVineKeyHelpView: ===
// STRUCT `ComicVineKeyHelpView:`: A data type or view that groups related fields/logic.
// This block defines how `ComicVineKeyHelpView:` behaves and is used throughout the app.
struct ComicVineKeyHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Get a ComicVine API Key")
                    .font(.title2.bold())

                Text("This key lets ComicVault auto-fill titles, issues, and publishers from barcodes or cover text.")
                    .foregroundStyle(.secondary)

                StepRow(number: 1, text: "Open the ComicVine API page.")
                Link("comicvine.gamespot.com/api", destination: URL(string: "https://comicvine.gamespot.com/api/")!)
                    .font(.callout)
                    .padding(.leading, 30)

                StepRow(number: 2, text: "Create or sign in to your free Giant Bomb / ComicVine account.")

                StepRow(number: 3, text: "Request an API key on the API page. You’ll receive a long alphanumeric key.")

                StepRow(number: 4, text: "Copy your key, then return to Settings → Online Metadata and paste it into “Your ComicVine API Key”.")

                Divider().padding(.vertical, 8)

                Text("Notes")
                    .font(.headline)
                Bullet("ComicVine’s API is intended for non-commercial use.")
                Bullet("We include an embedded default key so lookups work out of the box, but it shares limits across all users.")
                Bullet("Adding your own key gives you your own quota and more reliable lookups.")
            }
            .padding()
        }
        .navigationTitle("ComicVine Key Help")
    }
}

private struct StepRow: View {
    let number: Int
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number).")
                .font(.headline)
                .frame(width: 22, alignment: .trailing)
            Text(text)
        }
    }
}

private struct Bullet: View {
    let text: String
    init(_ t: String) { self.text = t }
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }
}
