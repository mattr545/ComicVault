//
//  CommunityLinksView.swift
//  ComicVault
//
//  File created on 10/20/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Shows curated links to the CryptoComics community, blog, and resources.
//
//  Running Edit Log
//  - 10-22-25: Replaced YouTube link with the correct channel URL.
//              Added Facebook, X (Twitter), Instagram, and Twitch links as provided by Matt. Kept Discord and LinkedIn.
//              Uses simple SF Symbols; we can swap to brand glyphs later.
//
//  NOTES
//  - Tapping a row opens the URL in Safari.
//  - If any URL is malformed, the row is disabled to avoid crashes.
//

import SwiftUI

struct CommunityLinksView: View {
    private struct LinkItem: Identifiable {
        let id = UUID()
        let title: String
        let systemImage: String
        let urlString: String
    }

    // MARK: - Data
    private let official: [LinkItem] = [
        .init(title: "CryptoComics Dashboard", systemImage: "link",
              urlString: "https://cryptocomics.com/dashboard")
    ]

    private let socials: [LinkItem] = [
        .init(title: "YouTube",   systemImage: "play.rectangle.fill",
              urlString: "https://www.youtube.com/c/CryptoComicsMarketplace/"),
        .init(title: "Facebook",  systemImage: "person.2.fill",
              urlString: "https://www.facebook.com/CryptoComicsMarketplace/"),
        .init(title: "X (Twitter)", systemImage: "xmark.square.fill",
              urlString: "https://x.com/CryptocomicsM/"),
        .init(title: "Instagram", systemImage: "camera.fill",
              urlString: "https://www.instagram.com/cryptocomicsmarketplace/"),
        .init(title: "Discord",   systemImage: "bubble.left.and.bubble.right.fill",
              urlString: "https://discord.com/invite/yRTTMAJQRX"),
        .init(title: "LinkedIn",  systemImage: "briefcase.fill",
              urlString: "https://www.linkedin.com/company/cryptocomicsmarketplace"),
        .init(title: "Twitch",    systemImage: "dot.radiowaves.left.and.right",
              urlString: "https://m.twitch.tv/cryptocomics/home")
    ]

    var body: some View {
        List {
            Section("Official") {
                ForEach(official) { item in LinkRow(item) }
            }
            Section("Social Media") {
                ForEach(socials) { item in LinkRow(item) }
            }
        }
        .navigationTitle("Community Links")
    }

    // MARK: - Row

    @ViewBuilder
    private func LinkRow(_ item: LinkItem) -> some View {
        if let url = URL(string: item.urlString) {
            Link(destination: url) {
                HStack(spacing: 12) {
                    Image(systemName: item.systemImage)
                        .foregroundStyle(Theme.brandPrimary)
                        .frame(width: 24)
                    Text(item.title)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        } else {
            // Defensive: if a URL is ever bad, show a disabled row.
            HStack(spacing: 12) {
                Image(systemName: item.systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text(item.title)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 6)
        }
    }
}
