//
//  WishlistView.swift
//  ComicVault
//
//  File created on 10/19/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: UI for displaying and editing wishlist items, with optional auto-estimates,
//               target alerts, and AI-based related-issue suggestions.
//
//  Running Edit Log
//  - 11-02-25: Added AI related-suggestions sheet.
//  - 11-07-25: Toolbar refinements.
//  - 11-08-25: Header normalization + AI prompt/parsing fixes.
//  - 11-09-25: Added UsageStats tracking for wishlist_adds.
//
//

import SwiftUI

struct WishlistView: View {

    @EnvironmentObject private var wishlist: WishlistViewModel
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @AppStorage(WishlistViewModel.autoEstimatesKey)
    private var autoEstimatesEnabled: Bool = true

    @AppStorage(WishlistViewModel.targetAlertsKey)
    private var targetAlertsEnabled: Bool = true

    @State private var showAddOrEdit = false
    @State private var editing: Comic? = nil

    // AI Related
    @State private var aiRelated: [String] = []
    @State private var showRelated = false
    @State private var busy = false

    private var useInlineTitle: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #else
        hSizeClass == .regular
        #endif
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(wishlist.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)

                        HStack(spacing: 8) {
                            if let n = item.issueNumber {
                                Text("Issue #\(n)")
                            }
                            if let p = item.publisher, !p.isEmpty {
                                Text(p)
                            }
                            if let b = item.barcode, !b.isEmpty {
                                Text("Barcode \(b)")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            if autoEstimatesEnabled, let est = item.currentValue {
                                Text("est. \(est.formatted(.currency(code: "USD")))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let target = item.wishlistTargetPrice, targetAlertsEnabled {
                                Text("target ≤ \(target.formatted(.currency(code: "USD")))")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.brandPrimary.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editing = item
                        showAddOrEdit = true
                    }
                }
                .onDelete(perform: wishlist.delete)
            }
            .listStyle(.plain)
            .navigationTitle("Wishlist")
            .navigationBarTitleDisplayMode(useInlineTitle ? .inline : .large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {

                        // AI "Suggest Related" button
                        Button {
                            Task {
                                busy = true
                                defer { busy = false }

                                do {
                                    let titles: [String] = wishlist.items.map { c in
                                        if let n = c.issueNumber {
                                            return "\(c.title) #\(n)"
                                        } else {
                                            return c.title
                                        }
                                    }

                                    guard !titles.isEmpty else {
                                        aiRelated = ["Add some wishlist items first."]
                                        showRelated = true
                                        return
                                    }

                                    let prompt = """
                                    Suggest 10 related key issues (titles only, one per line, no commentary)
                                    based on: \(titles.joined(separator: ", ")).
                                    """

                                    let response = try await AIClient.shared.complete(
                                        prompt: prompt,
                                        maxTokens: 200
                                    )

                                    aiRelated = response
                                        .components(separatedBy: .newlines)
                                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                        .filter { !$0.isEmpty }

                                    if aiRelated.isEmpty {
                                        aiRelated = ["No suggestions available."]
                                    }

                                    showRelated = true
                                } catch {
                                    aiRelated = ["No suggestions available."]
                                    showRelated = true
                                }
                            }
                        } label: {
                            if busy {
                                ProgressView()
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.title3)
                                    .accessibilityLabel("Suggest Related")
                            }
                        }

                        // Add new wishlist item
                        Button {
                            editing = nil
                            showAddOrEdit = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .accessibilityLabel("Add to Wishlist")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddOrEdit) {
            NavigationView {
                WishlistAddEditSheet(initial: editing) { title, issue, publisher, notes, barcode, target in
                    if let item = editing {
                        wishlist.update(
                            id: item.id,
                            title: title,
                            issue: issue,
                            publisher: publisher,
                            notes: notes,
                            barcode: barcode,
                            targetPrice: target
                        )
                    } else {
                        wishlist.add(
                            title: title,
                            issue: issue,
                            publisher: publisher,
                            notes: notes,
                            barcode: barcode,
                            targetPrice: target
                        )
                        UsageStats.increment("wishlist_adds")
                    }
                    editing = nil
                }
                .environmentObject(wishlist)
            }
        }
        .sheet(isPresented: $showRelated) {
            NavigationView {
                List {
                    ForEach(aiRelated, id: \.self) { s in
                        Text(s)
                    }
                }
                .navigationTitle("Related Suggestions")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showRelated = false }
                    }
                }
            }
        }
    }
}

#Preview {
    WishlistView()
        .environmentObject({
            let vm = WishlistViewModel()
            vm.items = []
            return vm
        }())
}
