//
//  ContentView.swift
//  ComicVault
//
//  File created on 10/15/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Early root view wrapper; may be superseded by ComicVaultApp/MainTabView.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        #if targetEnvironment(macCatalyst)
        // Running as a native Mac Catalyst app:
        // - Keep MainTabView so functionality is identical.
        // - Give it a comfortable minimum window size.
        MainTabView()
            .frame(minWidth: 900, minHeight: 600)
        #else
        // iPhone / iPad (and iOS-on-Mac “Designed for iPad”):
        // - Use the regular tab-based experience.
        MainTabView()
        #endif
    }
}

#Preview {
    ContentView()
        .environmentObject(CollectionViewModel())
        .environmentObject(WishlistViewModel())
        .environmentObject(SnapshotManager())
}
