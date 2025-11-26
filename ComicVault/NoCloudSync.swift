//
//  NoCloudSync.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Stubs and helpers for builds compiled without CloudKit support.
//

#if USE_CLOUDSYNC

import Foundation
import CloudKit
import Combine

@MainActor
final class NoCloudSync: ObservableObject, CloudSyncing {

    // Stable status when CloudKit is disabled
    @Published var accountStatus: CKAccountStatus = .noAccount

    // MARK: - CloudSyncing conformance (no-ops)

    func refreshAccountStatus() async { }

    func ensureZone() async { }

    func pullRemoteChanges(into vm: CollectionViewModel) async { }

    func pushLocalChanges(from vm: CollectionViewModel) async { }

    func upsert(_ comic: Comic) async { }

    func delete(id: UUID) async { }
}

#endif
