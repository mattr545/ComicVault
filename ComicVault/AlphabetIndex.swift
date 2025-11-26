//
//  AlphabetIndex.swift
//  ComicVault
//
//  File created on 10/18/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Helpers for alphabetical section indexing in list views.
//
//

import SwiftUI

/// Displays an A–Z vertical alphabet index on the right side of the screen.
/// When a letter is tapped, the bound `selected` value updates.
/// This is used for quick navigation (like Contacts or Music apps).
struct AlphabetIndex: View {
    @Binding var selected: String?

    /// Available index symbols (letters plus "#").
    private let letters = ["#", "A","B","C","D","E","F","G","H","I","J","K","L","M",
                           "N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]

    /// Preload a haptic generator so we don't recreate it per-tap.
    private let feedback = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        VStack(spacing: 2) {
            ForEach(letters, id: \.self) { letter in
                Button {
                    feedback.impactOccurred()
                    selected = letter
                } label: {
                    Text(letter)
                        .font(.caption2)
                        .fontWeight(selected == letter ? .bold : .regular)
                        .foregroundStyle(selected == letter ? .primary : .secondary)
                        .frame(width: 20, height: 16, alignment: .center)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Jump to \(letter)")
                }
            }
        }
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityElement(children: .contain)
    }
}
