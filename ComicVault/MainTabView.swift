//
//  MainTabView.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Main tab bar for Home, Collection, Portfolio, Wishlist, and More.
//
//  Running Edit Log
//  - 11-07-25: Unified tab layout and CloudSync-aware refresh.
//  - 11-08-25: Header + style normalization.
//  - 11-09-25: Restored clean tab wiring after analytics experiment (no UsageStats dependency).
//  - 11-10-25: Switched to new two-parameter onChange(for:scenePhase) and
//              qualified PortfolioView to resolve ambiguous init() without changing behavior.
//

import SwiftUI

struct MainTabView: View {

    @EnvironmentObject private var collectionVM: CollectionViewModel
    @EnvironmentObject private var wishlistVM: WishlistViewModel
    @EnvironmentObject private var snapshotMgr: SnapshotManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            // HOME
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            // COLLECTION
            CollectionView()
                .onAppear {
                    if CLOUDSYNC_ENABLED {
                        collectionVM.beginCloudSync()
                    }
                }
                .tabItem {
                    Label("Collection", systemImage: "books.vertical.fill")
                }

            // PORTFOLIO
            ComicVault.PortfolioView()
                .tabItem {
                    Label("Portfolio", systemImage: "chart.line.uptrend.xyaxis")
                }

            // WISHLIST
            WishlistView()
                .tabItem {
                    Label("Wishlist", systemImage: "star.fill")
                }

            // MORE
            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
        }
        .tint(Theme.brandPrimary)
        .onChange(of: scenePhase) { _, newPhase in
            guard CLOUDSYNC_ENABLED else { return }
            if newPhase == .active {
                Task {
                    await collectionVM.refreshFromCloud()
                }
            }
        }
    }
}

#if DEBUG
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(CollectionViewModel())
            .environmentObject(WishlistViewModel())
            .environmentObject(SnapshotManager())
            .tint(Theme.brandPrimary)
    }
}
#endif
