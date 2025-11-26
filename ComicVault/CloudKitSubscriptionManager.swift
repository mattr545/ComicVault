//
//  CloudKitSubscriptionManager.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Manages CloudKit subscriptions and push notification registrations.
//

import Foundation
import Combine

// Always available so views can subscribe safely even in local-only builds.
extension Notification.Name {
    static let cloudKitDidChange = Notification.Name("cloudKitDidChange")
}

#if USE_CLOUDSYNC
import CloudKit

@MainActor
final class CloudKitSubscriptionManager: ObservableObject {

    // Concrete singleton – no default arg in init to avoid link-time weirdness.
    static let shared = CloudKitSubscriptionManager(container: CKContainer.default())

    private let container: CKContainer
    private let database: CKDatabase
    private let subscriptionID = "com.comicvault.subs.comic.changes.v1"

    private init(container: CKContainer) {
        self.container = container
        self.database  = container.privateCloudDatabase
    }

    /// Idempotently ensure a query subscription exists on the "Comic" record type.
    func registerComicChangeSubscription() async {
        // Only attempt when the account is available.
        do {
            guard try await container.accountStatus() == .available else { return }
        } catch {
            return
        }

        // Already present?
        do {
            let existing = try await database.allSubscriptions()
            if existing.contains(where: { $0.subscriptionID == subscriptionID }) { return }
        } catch {
            // fall through and try to create it
        }

        let sub = CKQuerySubscription(
            recordType: "Comic",
            predicate: NSPredicate(value: true),
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true   // silent push
        sub.notificationInfo = info

        do {
            _ = try await database.save(sub)
            // Optional: nudge the app that iCloud changed (useful for testing flows).
            NotificationCenter.default.post(name: .cloudKitDidChange, object: nil)
        } catch {
            #if DEBUG
            print("CK subscription save error:", error)
            #endif
        }
    }
}

#else

/// Local-only stub so call sites don't need `#if` guards.
/// Keeps the same API and does nothing.
@MainActor
final class CloudKitSubscriptionManager: ObservableObject {
    static let shared = CloudKitSubscriptionManager()
    private init() {}
    func registerComicChangeSubscription() async { /* no-op */ }
}

#endif
