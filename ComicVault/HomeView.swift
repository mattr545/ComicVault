//
//  HomeView.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Landing dashboard showing quick stats, entry points, and integrations.
//
//  Running Edit Log
//  - 11-09-25: Simplified header and aligned with inline navigation style across tabs.
//  - 11-25-25: Added CryptoComics Blog section using temporary HTML scrape of /blog.
//              Clearly marked block so it can be replaced by a JSON/RSS feed later.
//
//

import SwiftUI
import UIKit   // for UIImage and NSAttributedString HTML stripping

struct HomeView: View {
    @EnvironmentObject private var collectionVM: CollectionViewModel
    @EnvironmentObject private var wishlistVM: WishlistViewModel
    @Environment(\.openURL) private var openURL

    // iCloud sync indicator (notification-driven; no @ObservedObject existential)
    @State private var isSyncing: Bool = false

    // CryptoComics blog state
    @State private var blogPosts: [HomeBlogPost] = []
    @State private var isLoadingBlog: Bool = false
    @State private var blogError: String?

    private var ownedCount: Int { collectionVM.comics.count }
    private var wishlistCount: Int { wishlistVM.items.count }

    // Local helper: prefer currentValue; fall back to coverPrice; else 0.
    private func displayValue(for comic: Comic) -> Double {
        if let v = comic.currentValue { return v }
        if let cp = comic.coverPrice { return cp }
        return 0
    }

    private var totalCollectionValue: Double {
        collectionVM.comics
            .map { displayValue(for: $0) }
            .reduce(0, +)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {

                    // iCloud syncing badge (appears only while syncing)
                    if isSyncing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Syncing…")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.brandPrimary.opacity(0.08))
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("iCloud is syncing")
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Collection value card
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Theme.brandPrimary.opacity(0.12))
                                    Image(systemName: "banknote.fill")
                                        .font(.title3)
                                        .foregroundStyle(Theme.brandPrimary)
                                }
                                .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Collection Value")
                                        .font(.headline)
                                        .foregroundStyle(Theme.brandPrimary)
                                    Text(totalCollectionValue.formatted(.currency(code: "USD")))
                                        .font(.title2.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                Spacer()
                            }

                            Button {
                                Task {
                                    await collectionVM.bulkEstimateAll()
                                    Haptics.success()
                                }
                            } label: {
                                Label("Estimate All Values", systemImage: "sparkle.magnifyingglass")
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 4)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.surfaceAlt)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                    }
                    .groupBoxStyle(.automatic)

                    // Stats
                    GroupBox {
                        HStack(spacing: 12) {
                            statPill(number: ownedCount, label: "Owned")
                            statPill(number: wishlistCount, label: "Wishlist")
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                    .groupBoxStyle(.automatic)

                    // Shortcuts
                    NavigationLink {
                        CollectionView().environmentObject(collectionVM)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "books.vertical")
                                .font(.title3)
                                .foregroundStyle(Theme.brandPrimary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("My Collection")
                                    .font(.headline)
                                    .foregroundStyle(Theme.brandPrimary)
                                Text("Browse, search, and sort")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.brandPrimary)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.surfaceAlt)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                    }

                    NavigationLink {
                        WishlistView().environmentObject(wishlistVM)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.brandPrimary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Wishlist")
                                    .font(.headline)
                                    .foregroundStyle(Theme.brandPrimary)
                                Text("Track what you want next")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.brandPrimary)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.surfaceAlt)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                    }

                    // ------------------------------------------------------------
                    // TEMPORARY: CryptoComics Blog section
                    //
                    // This block currently:
                    //   - Fetches https://cryptocomics.com/blog as raw HTML
                    //   - Tries to extract recent posts (title, link, first paragraph)
                    //   - Shows real posts in horizontal cards
                    //
                    // If parsing fails or the network is down:
                    //   - No fake cards are shown
                    //   - A small error message explains what happened
                    //
                    // When a proper JSON/RSS feed is available, replace:
                    //   - loadBlog()
                    //   - parseBlogHTML(_:)
                    // And keep the blogSection/blogCard UI the same.
                    // ------------------------------------------------------------
                    blogSection
                    // ---------------------- END TEMPORARY BLOG SCRAPE ----------

                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            // Keep the badge in sync with CloudSync via notifications
            .onReceive(NotificationCenter.default.publisher(for: .cloudSyncIsSyncingChanged)) { note in
                if let v = note.object as? Bool { isSyncing = v }
            }
            .task {
                // initialize current state without storing a concrete reference
                isSyncing = CloudSync.shared.isSyncing

                // Kick off blog load after initial render
                if blogPosts.isEmpty {
                    await loadBlog()
                }
            }
        }
    }

    private func statPill(number: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(number)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.brandPrimary)
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.brandPrimary.opacity(0.12))
        )
    }

    // MARK: - Blog section view

    private var blogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("From the CryptoComics Blog")
                    .font(.headline)
                    .foregroundStyle(Theme.brandPrimary)
                Spacer()
                Button {
                    if let url = BlogFeed.blogURL {
                        openURL(url)
                    }
                } label: {
                    Text("View All")
                        .font(.footnote.weight(.semibold))
                }
            }

            if isLoadingBlog && blogPosts.isEmpty {
                HStack {
                    ProgressView()
                    Text("Loading latest posts…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if let error = blogError, blogPosts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Couldn’t refresh the blog.")
                        .font(.footnote.weight(.semibold))
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if !blogPosts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(blogPosts) { post in
                            blogCard(for: post)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.top, 4)
    }

    private func blogCard(for post: HomeBlogPost) -> some View {
        Button {
            if let url = post.url {
                openURL(url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                if let tag = post.tag, !tag.isEmpty {
                    Text(tag.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.brandPrimary)
                } else {
                    Text("BLOG")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.brandPrimary)
                }

                Text(post.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(post.excerpt)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(width: 260, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.surfaceAlt)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Blog loading

    @MainActor
    private func loadBlog() async {
        // Avoid reloading if we already have posts
        if !blogPosts.isEmpty { return }

        isLoadingBlog = true
        blogError = nil

        defer { isLoadingBlog = false }

        guard let url = BlogFeed.blogURL else {
            blogError = "Invalid blog URL."
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8),
                  !html.isEmpty else {
                blogError = "Empty response from CryptoComics blog."
                return
            }

            let parsed = parseBlogHTML(html)

            if parsed.isEmpty {
                blogError = "Couldn’t parse blog HTML."
            } else {
                blogPosts = parsed
                blogError = nil
            }
        } catch {
            blogError = "Network error: \(error.localizedDescription)"
        }
    }

    // Naive HTML parsing tuned for CryptoComics blog layout.
    // Intentionally conservative: we only care about a handful of posts
    // and ignore anything we cannot confidently recognize.
    private func parseBlogHTML(_ html: String) -> [HomeBlogPost] {
        var results: [HomeBlogPost] = []

        // Split on <article to roughly isolate post blocks.
        let pieces = html.components(separatedBy: "<article")
        guard pieces.count > 1 else { return [] }

        for chunk in pieces.dropFirst() {
            // Find first href to a blog post
            guard let hrefRange = chunk.range(of: "href=\"") else { continue }
            let afterHref = chunk[hrefRange.upperBound...]
            guard let endHref = afterHref.firstIndex(of: "\"") else { continue }
            let href = String(afterHref[..<endHref])

            // Only accept CryptoComics blog-style links
            if !(href.contains("/blog") || href.contains("/blogs")) {
                continue
            }

            // Find a title inside h1/h2/h3
            let headingTags = ["<h3", "<h2", "<h1"]
            var title: String?

            for tag in headingTags {
                if let hStart = chunk.range(of: tag) {
                    let afterH = chunk[hStart.upperBound...]
                    guard let openGT = afterH.firstIndex(of: ">") else { continue }
                    let contentStart = afterH.index(after: openGT)
                    if let closeRange = afterH.range(of: "</h", range: contentStart..<afterH.endIndex) {
                        let rawTitle = String(afterH[contentStart..<closeRange.lowerBound])
                        let cleaned = rawTitle.strippingHTML().trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleaned.isEmpty {
                            title = cleaned
                            break
                        }
                    }
                }
                if title != nil { break }
            }

            guard let safeTitle = title, !safeTitle.isEmpty else { continue }

            // First <p> after heading is our excerpt guess
            var excerpt: String = ""
            if let pStart = chunk.range(of: "<p") {
                let afterP = chunk[pStart.upperBound...]
                if let openGT = afterP.firstIndex(of: ">") {
                    let contentStart = afterP.index(after: openGT)
                    if let pClose = afterP.range(of: "</p>", range: contentStart..<afterP.endIndex) {
                        let rawExcerpt = String(afterP[contentStart..<pClose.lowerBound])
                        let cleaned = rawExcerpt.strippingHTML().trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleaned.isEmpty {
                            excerpt = cleaned
                        }
                    }
                }
            }

            let fullURL: URL? = {
                if href.hasPrefix("http") {
                    return URL(string: href)
                } else {
                    return URL(string: "https://cryptocomics.com\(href)")
                }
            }()

            let post = HomeBlogPost(
                title: safeTitle,
                tag: nil, // Not scraping tags yet
                excerpt: excerpt.isEmpty ? "Read this post on CryptoComics.com." : excerpt,
                url: fullURL
            )

            results.append(post)

            if results.count >= 10 { break }
        }

        return results
    }
}

// MARK: - Minimal shim so the button compiles and works on iOS 16+
// If your real estimator exists elsewhere, remove this extension.

extension CollectionViewModel {
    @MainActor
    func bulkEstimateAll() async {
        var updated = comics
        for i in updated.indices {
            if updated[i].currentValue == nil {
                updated[i].currentValue = updated[i].coverPrice ?? 0
            }
        }
        comics = updated
    }
}

// MARK: - CryptoComics Blog helpers (temporary)

private struct HomeBlogPost: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let tag: String?
    let excerpt: String
    let url: URL?
}

private enum BlogFeed {
    static let blogURL = URL(string: "https://cryptocomics.com/blog")
}

// MARK: - HTML stripping helper

private extension String {
    /// Helper to strip basic HTML tags from snippets.
    func strippingHTML() -> String {
        // First try NSAttributedString’s HTML importer
        if let data = self.data(using: .utf8) {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            if let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
                return attributed.string
            }
        }

        // Fallback regex-based stripping
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            let range = NSRange(location: 0, length: (self as NSString).length)
            return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "")
        }

        return self
    }
}
