//
//  CCBlogSectionView.swift
//  ComicVault
//
//  File created on 11/25/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Compact CryptoComics blog strip for the Home screen.
//

import SwiftUI
import SafariServices

struct CCBlogSectionView: View {
    @StateObject private var store = CCBlogStore()
    @State private var selectedURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CryptoComics Blog")
                    .font(.headline)
                Spacer()
                if store.isLoading {
                    ProgressView()
                        .scaleEffect(0.75)
                }
            }

            if let message = store.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.posts) { post in
                        blogCard(for: post)
                            .onTapGesture {
                                selectedURL = post.url
                            }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .task {
            if store.posts.isEmpty {
                await store.refresh()
            }
        }
        .sheet(item: $selectedURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func blogCard(for post: CCBlogPost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.12))

                if let url = post.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 220, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(post.category.uppercased())
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.2))
                )

            Text(post.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            Text(post.summary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(width: 220, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// Simple Safari wrapper
private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
