//
//  ReorderImagesSheet.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Sheet UI for reordering multiple images associated with a comic.
//
//  Running Edit Log
//  - 10-23-25: Manual drag-and-drop reorder for supplemental photos.
//
//  NOTES
//  We show a simple List with thumbnails and move handles. When the user taps Done,
//  we pass the new order back up to persist.
//

import SwiftUI
import UIKit

struct ReorderImagesSheet: View {
    let images: [Data]
    var onDone: ([Data]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var working: [Data]

    init(images: [Data], onDone: @escaping ([Data]) -> Void) {
        self.images = images
        self.onDone = onDone
        _working = State(initialValue: images)
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(working.indices, id: \.self) { i in
                    HStack(spacing: 12) {
                        if let ui = UIImage(data: working[i]) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipped()
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.black.opacity(0.06))
                                )
                        } else {
                            Color.gray
                                .frame(width: 60, height: 60)
                                .cornerRadius(6)
                        }
                        Text("Photo \(i + 1)")
                        Spacer()
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                    }
                }
                .onMove { indices, newOffset in
                    working.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .navigationTitle("Reorder Photos")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    EditButton() // toggles move handles
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Done") {
                        onDone(working)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
