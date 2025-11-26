//
//  CollectionView.swift
//  ComicVault
//
//  File created on 10/15/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Main collection grid/list view for browsing owned comics.
//
//  Running Edit Log
//  - 11-07-25: Adaptive nav title for large screens.
//  - 11-09-25: Normalized to inline navigation style for consistency.
//
//

import SwiftUI

struct CollectionView: View {
    @EnvironmentObject private var vm: CollectionViewModel

    @State private var searchText: String = ""
    @State private var presentAdd: Bool = false
    @State private var presentQuickAdd: Bool = false
    @State private var sortByTitle: Bool = true
    @State private var showValueExpanded: Bool = true

    // MARK: - Derived

    private var filteredComics: [Comic] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = vm.comics
        let filtered = q.isEmpty
            ? base
            : base.filter { c in
                let hay = [
                    c.title,
                    c.publisher ?? "",
                    c.notes ?? "",
                    c.barcode ?? ""
                ].joined(separator: " ").lowercased()
                return hay.contains(q)
            }

        if sortByTitle {
            return filtered.sorted { a, b in
                a.title.caseInsensitiveCompare(b.title) == .orderedAscending
            }
        } else {
            return filtered.sorted { a, b in
                let av = a.currentValue ?? 0
                let bv = b.currentValue ?? 0
                if av != bv { return av > bv }
                return a.title.caseInsensitiveCompare(b.title) == .orderedAscending
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            List {
                // Inline sync badge (only shows while syncing)
                Section {
                    SyncStatusBadge()
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                }

                // Sparkline / Totals (collapsible)
                Section {
                    DisclosureGroup(isExpanded: $showValueExpanded) {
                        CollectionSparklineHeader(mode: .full)
                            .environmentObject(vm)
                            .padding(.top, 8)
                    } label: {
                        CollectionSparklineHeader(mode: .compact)
                            .environmentObject(vm)
                    }
                    .animation(.default, value: showValueExpanded)
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                .listRowSeparator(.hidden)

                // Toggle sort
                Section {
                    Picker("Sort", selection: $sortByTitle) {
                        Text("Title").tag(true)
                        Text("Value").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                // Empty state
                if filteredComics.isEmpty {
                    Section {
                        AlphabetIndexBar { tapped in
                            searchText = String(tapped)
                        }
                        .padding(.bottom, 6)

                        VStack(spacing: 10) {
                            Image(systemName: "books.vertical")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No comics yet")
                                .font(.headline)
                            Text("Tap Add to start your collection or use Quick Add to scan barcodes.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                    }
                } else {
                    // Comics list
                    Section {
                        ForEach(filteredComics) { comic in
                            NavigationLink(
                                destination: ComicDetailView(comic: comic)
                                    .environmentObject(vm)
                            ) {
                                comicRow(comic)
                            }
                        }
                        .onDelete(perform: deleteComics)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        presentQuickAdd = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                    Button {
                        presentAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search title, publisher, notes…"
            )
            // MARK: - Sheets
            .sheet(isPresented: $presentAdd) {
                NavigationView {
                    AddComicView<CollectionViewModel>()
                        .environmentObject(vm)
                }
            }
            .sheet(isPresented: $presentQuickAdd) {
                NavigationView {
                    QuickAddView()
                        .environmentObject(vm)
                }
            }
        }
    }

    // MARK: - Row

    private func comicRow(_ c: Comic) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.brandPrimary.opacity(0.15))
                    .frame(width: 34, height: 34)
                Text(initials(c.title))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.brandPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(c.displayTitle)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let p = c.publisher, !p.isEmpty {
                        Text(p).foregroundStyle(.secondary)
                    }
                    if let y = c.year {
                        Text("• \(y)").foregroundStyle(.secondary)
                    }
                    if let v = c.volume {
                        Text("• Vol. \(v)").foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .lineLimit(1)
            }

            Spacer()

            Text(valueText(c.currentValue))
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func deleteComics(at offsets: IndexSet) {
        let toDelete = offsets.compactMap { idx -> Int? in
            let id = filteredComics[idx].id
            return vm.comics.firstIndex { $0.id == id }
        }
        for i in toDelete.sorted(by: >) {
            vm.comics.remove(at: i)
        }
    }

    // MARK: - Helpers

    private func valueText(_ v: Double?) -> String {
        guard let v else { return "—" }
        return v.formatted(.currency(code: "USD"))
    }

    private func initials(_ s: String) -> String {
        let parts = s
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
        return parts.joined()
    }
}

// MARK: - Preview

#Preview {
    CollectionView_PreviewContainer()
}

private struct CollectionView_PreviewContainer: View {
    @StateObject private var vm = CollectionViewModel()

    var body: some View {
        NavigationView {
            CollectionView()
                .environmentObject(vm)
                .tint(Theme.brandPrimary)
        }
        .onAppear {
            if vm.comics.isEmpty {
                let a = Comic.sample
                var b = Comic.sample
                b.id = UUID()
                b.title = "Detective Comics"
                b.issueNumber = 27
                b.publisher = "DC"
                b.currentValue = 1_250_000
                b.year = 1939
                vm.comics = [a, b]
            }
        }
    }
}

// MARK: - Alphabet Index Bar

fileprivate struct AlphabetIndexBar: View {
    let onTap: (Character) -> Void
    private let letters: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(letters, id: \.self) { ch in
                    Button {
                        onTap(ch)
                    } label: {
                        Text(String(ch))
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                            .background(Theme.brandPrimary.opacity(0.12), in: Circle())
                            .foregroundStyle(Theme.brandPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Jump to \(String(ch))")
                }
            }
            .padding(.horizontal, 8)
        }
    }
}
