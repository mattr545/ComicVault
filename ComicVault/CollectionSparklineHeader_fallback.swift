//
//  CollectionSparklineHeader_fallback.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Fallback sparkline header implementation for older OS or environments.
//

import SwiftUI

// Only compile this fallback when the Charts framework is not present
#if !canImport(Charts)

struct CollectionSparklineHeader: View {
    enum Mode { case full, compact }
    let mode: Mode

    var body: some View {
        // Minimal header so CollectionView can compile on iOS 15
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Portfolio Value")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if mode == .full {
                Text("Sparklines require iOS 16 or newer.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#endif
