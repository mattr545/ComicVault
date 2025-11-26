//
//  ComicVaultApp.swift
//  ComicVault
//
//  File created on 10/15/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: App entry point, environment wiring, theming, CloudKit hooks, snapshots, and auto price tracking.
//
//  Running Edit Log
//  - 11-07-25: Unified startup, CloudSync handling, and auto price tracker integration.
//  - 11-08-25: Header + style normalization.
//  - 11-09-25: Updated onChange handling via onChangeCompat for iOS 17+.
//
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import Combine
#if USE_CLOUDSYNC
import CloudKit
#endif

@main
struct ComicVaultApp: App {

    @AppStorage("app.appearance")
    private var appAppearanceRaw: String = AppAppearance.system.rawValue

    @StateObject private var collectionVM = CollectionViewModel()
    @StateObject private var wishlistVM   = WishlistViewModel()
    @StateObject private var snapshotMgr  = SnapshotManager()

    @State private var showLaunch = true
    @Environment(\.scenePhase) private var scenePhase

    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        Self.setupBrandAppearance()
    }

    var body: some Scene {
        WindowGroup {
            mainContent()
                .preferredColorScheme(AppAppearance(rawValue: appAppearanceRaw)?.scheme)
                .tint(Theme.brandPrimary)
                .buttonStyle(HapticButtonStyle())
                .environmentObject(collectionVM)
                .environmentObject(wishlistVM)
                .environmentObject(snapshotMgr)

                // Local startup
                .onAppear {
                    snapshotMgr.refresh()
                    snapshotMgr.performDailySnapshotIfNeeded(comics: collectionVM.comics)
                    PriceService.runAutoUpdateIfNeeded(on: collectionVM)
                    wishlistVM.refreshEstimatesIfNeeded()
                }

            #if USE_CLOUDSYNC
                // React to silent CloudKit pushes
                .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
                    Task {
                        await CloudSync.current().pullRemoteChanges(into: collectionVM)
                    }
                }

                // CloudKit bootstrap + initial pull
                .task {
                    await CloudSync.current().refreshAccountStatus()
                    await CloudSync.current().ensureZone()
                    await CloudKitSubscriptionManager.shared.registerComicChangeSubscription()
                    await CloudSync.current().pullRemoteChanges(into: collectionVM)
                }

                // Foreground: snapshots + pull + auto price + wishlist
                .onChangeCompat(of: scenePhase) { phase in
                    if phase == .active {
                        snapshotMgr.performDailySnapshotIfNeeded(comics: collectionVM.comics)
                        Task {
                            await CloudSync.current().pullRemoteChanges(into: collectionVM)
                        }
                        PriceService.runAutoUpdateIfNeeded(on: collectionVM)
                        wishlistVM.refreshEstimatesIfNeeded()
                    }
                }

                // Push local edits
                .onReceive(collectionVM.$comics) { _ in
                    Task {
                        await CloudSync.current().pushLocalChanges(from: collectionVM)
                    }
                }
            #else
                // Non-Cloud: snapshots + auto tracker + wishlist
                .onChangeCompat(of: scenePhase) { phase in
                    if phase == .active {
                        snapshotMgr.performDailySnapshotIfNeeded(comics: collectionVM.comics)
                        PriceService.runAutoUpdateIfNeeded(on: collectionVM)
                        wishlistVM.refreshEstimatesIfNeeded()
                    }
                }
            #endif
        }
    }
}

// MARK: - View helpers

private extension ComicVaultApp {
    @ViewBuilder
    func mainContent() -> some View {
        Group {
            if showLaunch {
                LaunchView { showLaunch = false }
            } else {
                MainTabView()
            }
        }
    }

    static func setupBrandAppearance() {
        #if canImport(UIKit)
        let brand = UIColor(Theme.brandPrimary)
        let bg    = UIColor.systemBackground

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = bg
        nav.titleTextAttributes      = [.foregroundColor: brand]
        nav.largeTitleTextAttributes = [.foregroundColor: brand]
        UINavigationBar.appearance().standardAppearance   = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance    = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = bg
        [tab.stackedLayoutAppearance,
         tab.inlineLayoutAppearance,
         tab.compactInlineLayoutAppearance].forEach { item in
            item.selected.iconColor = brand
            item.selected.titleTextAttributes = [.foregroundColor: brand]
        }
        UITabBar.appearance().standardAppearance   = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        #endif
    }
}
