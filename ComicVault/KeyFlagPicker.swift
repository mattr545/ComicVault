//
//  KeyFlagPicker.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: UI control to select key issue flags (first appearance, iconic cover, etc.).
//

import SwiftUI

struct KeyFlagPicker: View {
    @Binding var selection: Set<KeyFlag>

    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(KeyFlag.allCases, id: \.self) { flag in
                Toggle(isOn: Binding(
                    get: { selection.contains(flag) },
                    set: { newValue in
                        if newValue { selection.insert(flag) } else { selection.remove(flag) }
                    }
                )) {
                    Text(label(for: flag))
                        .font(.callout)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
            }
        }
    }

    private func label(for flag: KeyFlag) -> String {
        switch flag {
        case .firstAppearance:   return "First Appearance"
        case .origin:            return "Origin"
        case .death:             return "Death"
        case .cameo:             return "Cameo"
        case .majorEvent:        return "Major Event"
        case .iconicCover:       return "Iconic Cover"
        case .errorPrint:        return "Error Print"
        case .newsstand:         return "Newsstand"
        case .direct:            return "Direct"
        case .retailerIncentive: return "Retailer Incentive"
        case .signed:            return "Signed"
        }
    }
}
