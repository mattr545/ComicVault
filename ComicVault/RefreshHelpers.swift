//
//  RefreshHelpers.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Pull-to-refresh and data reload helper utilities.
//
//  Adds a simple compatibility wrapper for pull-to-refresh.
//  iOS 15 and newer: uses .refreshable directly.
//

import SwiftUI

public struct RefreshableCompat: ViewModifier {
    let action: () async -> Void

    public func body(content: Content) -> some View {
        content
            .refreshable {
                await action()
            }
    }
}

public extension View {
    /// Adds pull-to-refresh to a scrollable container. Uses the native API on iOS 15+.
    func refreshableCompat(_ action: @escaping () async -> Void) -> some View {
        modifier(RefreshableCompat(action: action))
    }
}

/*
 USAGE EXAMPLE inside CollectionView:

 List { ... }
 .refreshableCompat {
     await CloudSync.shared.refreshFromCloud(collectionVM: vm)
 }

 You can also trigger a local refresh only, for example:
 .refreshableCompat {
     await vmLocalRefresh()
 }
*/
