//
//  CloudSyncManager.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Core CloudKit synchronization engine for Comic records.
//

import Foundation

#if USE_CLOUDSYNC
import CloudKit

/// Thin wrapper over the user's *private* CloudKit database.
/// v1.0: fetch-all on start, push on local writes, simple pull on foreground.
/// Conflicts: last-write-wins via `modifiedAt`.
@available(iOS 16.0, *)
final class CloudSyncManager {

    static let shared = CloudSyncManager()

    private let container: CKContainer
    private let db: CKDatabase

    private init() {
        container = CKContainer.default()
        db = container.privateCloudDatabase
    }

    // MARK: - Public API

    /// Fetch **all** Comic records from the private DB.
    func fetchAll() async throws -> [Comic] {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: CKComicRecordType, predicate: predicate)

        var results: [Comic] = []
        var cursor: CKQueryOperation.Cursor?

        // First page
        let first = try await db.records(matching: query)
        results.append(
            contentsOf: first.matchResults.compactMap { _, result in
                if case .success(let rec) = result { return CKComicMapper.toComic(rec) }
                return nil
            }
        )
        cursor = first.queryCursor

        // Remaining pages (if any)
        while let cur = cursor {
            let page = try await db.records(continuingMatchFrom: cur)
            results.append(
                contentsOf: page.matchResults.compactMap { _, result in
                    if case .success(let rec) = result { return CKComicMapper.toComic(rec) }
                    return nil
                }
            )
            cursor = page.queryCursor
        }

        return results
    }

    /// Insert or update a Comic (last-writer-wins via `modifiedAt`).
    func upsert(_ comic: Comic) async throws {
        var updated = comic
        updated.modifiedAt = Date()
        let rec = CKComicMapper.toRecord(updated)
        _ = try await db.save(rec)
    }

    /// Delete by ID.
    func delete(id: UUID) async throws {
        let rid = CKComicMapper.recordID(for: id)
        _ = try await db.deleteRecord(withID: rid)
    }
}

#else

/// Local-only shim so call sites compile without CloudKit.
final class CloudSyncManager {

    static let shared = CloudSyncManager()
    private init() {}

    func fetchAll() async throws -> [Comic] { [] }
    func upsert(_ comic: Comic) async throws { /* no-op */ }
    func delete(id: UUID) async throws { /* no-op */ }
}

#endif
