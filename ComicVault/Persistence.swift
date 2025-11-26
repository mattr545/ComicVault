//
//  Persistence.swift
//  ComicVault
//
//  File created on 10/15/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Local persistence helpers for storing user data and settings.
//
//
//  Purpose:
//  - Local-first persistence of [Comic] to JSON (fast offline).
//  - Optional CloudKit Private Database sync (single custom zone).
//  - Gentle conflict policy (last-write-wins via a signal date).
//
//  This file compiles in two modes controlled by the build flag USE_CLOUDSYNC.
//  - When USE_CLOUDSYNC is defined: JSON + CloudKit sync.
//  - When not defined: JSON-only with identical API surface.
//
import Foundation

#if USE_CLOUDSYNC
import CloudKit
#if canImport(UIKit)
import UIKit
#endif
#endif

// MARK: - Persistence (singleton)

@MainActor
final class Persistence {

    static let shared = Persistence()

    // Local cache path
    private let localFilename = "comics.json"

    // In-memory cache (source of truth for local writes)
    private var cachedComics: [Comic] = []

    private init() {
        // nothing else needed for local mode; CloudKit wiring is inside #if blocks
    }

    // MARK: - Public API ------------------------------------------------------

    /// Load local cache from disk and then refresh from cloud (when enabled).
    func loadAll() async -> [Comic] {
        cachedComics = loadLocal()
        #if USE_CLOUDSYNC
        Task { await refreshFromCloud() }
        #endif
        return cachedComics
    }

    /// Save or update a Comic locally, then push to cloud (when enabled).
    func upsertComic(_ comic: Comic) async {
        upsertLocal(comic)
        persistLocal()
        #if USE_CLOUDSYNC
        Task { try? await self.pushComic(comic) }
        #endif
    }

    /// Remove a Comic locally and in cloud (when enabled).
    func deleteComic(_ comic: Comic) async {
        deleteLocal(comic)
        persistLocal()
        #if USE_CLOUDSYNC
        Task { try? await self.deleteRemoteComic(id: comic.id) }
        #endif
    }

    /// Force a pull from cloud and merge into local (no-op in local mode).
    func refreshFromCloud() async {
        #if USE_CLOUDSYNC
        do {
            try await ensureZoneExists()
            let remote = try await fetchAllRemote()
            let merged = merge(local: cachedComics, remote: remote)
            cachedComics = merged
            persistLocal()
        } catch {
            // Silent failure is acceptable; app still works offline.
        }
        #else
        // Local-only: nothing to pull.
        #endif
    }

    /// Expose current cache to ViewModels
    var currentComics: [Comic] { cachedComics }
}

// MARK: - Local JSON ----------------------------------------------------------

private extension Persistence {

    func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func localURL() -> URL {
        documentsURL().appendingPathComponent(localFilename)
    }

    func loadLocal() -> [Comic] {
        let url = localURL()
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Comic].self, from: data)) ?? []
    }

    func persistLocal() {
        let url = localURL()
        do {
            let data = try JSONEncoder().encode(cachedComics)
            try data.write(to: url, options: .atomic)
        } catch {
            // Ignore local write failures (disk full, etc).
        }
    }

    func upsertLocal(_ comic: Comic) {
        if let idx = cachedComics.firstIndex(where: { $0.id == comic.id }) {
            cachedComics[idx] = comic
        } else {
            cachedComics.append(comic)
        }
    }

    func deleteLocal(_ comic: Comic) {
        cachedComics.removeAll { $0.id == comic.id }
    }
}

#if USE_CLOUDSYNC
// MARK: - CloudKit (Zone/Fetch/Push/Delete) ----------------------------------

private extension Persistence {

    var container: CKContainer { CKContainer.default() }
    var db: CKDatabase { container.privateCloudDatabase }
    var recordType: String { "Comic" }
    var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: "ComicVaultZone", ownerName: CKCurrentUserDefaultName)
    }

    func ensureZoneExists() async throws {
        // Try to save zone; ignore if it already exists.
        let zone = CKRecordZone(zoneID: zoneID)
        do {
            _ = try await db.modifyRecordZones(saving: [zone], deleting: [])
        } catch {
            // If it's an "already exists" case, continue silently.
        }
    }

    func fetchAllRemote() async throws -> [Comic] {
        // Query all records in zone
        let pred = NSPredicate(value: true)
        let q    = CKQuery(recordType: recordType, predicate: pred)
        var out: [Comic] = []

        var cursor: CKQueryOperation.Cursor?
        repeat {
            let page = try await runQuery(q, cursor: cursor)
            out.append(contentsOf: page.items)
            cursor = page.cursor
        } while cursor != nil

        return out
    }

    func runQuery(_ query: CKQuery,
                  cursor: CKQueryOperation.Cursor?) async throws -> (items: [Comic], cursor: CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { cont in
            let op: CKQueryOperation = cursor != nil ? CKQueryOperation(cursor: cursor!) : CKQueryOperation(query: query)
            op.zoneID = zoneID

            var found: [Comic] = []

            op.recordMatchedBlock = { _, result in
                if case .success(let rec) = result, let comic = self.comic(from: rec) {
                    found.append(comic)
                }
            }
            op.queryResultBlock = { result in
                switch result {
                case .success(let newCursor):
                    cont.resume(returning: (found, newCursor))
                case .failure(let error):
                    cont.resume(throwing: error)
                }
            }
            self.db.add(op)
        }
    }

    func pushComic(_ comic: Comic) async throws {
        try await ensureZoneExists()
        let recordID = CKRecord.ID(recordName: comic.id.uuidString, zoneID: zoneID)
        let record: CKRecord

        // Fetch existing or create new
        if let existing = try? await db.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: recordType, recordID: recordID)
        }

        apply(comic: comic, to: record)

        _ = try await db.modifyRecords(saving: [record], deleting: [])
    }

    func deleteRemoteComic(id: UUID) async throws {
        try await ensureZoneExists()
        let rid = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        do {
            _ = try await db.modifyRecords(saving: [], deleting: [rid])
        } catch {
            // Ignore if not found.
        }
    }
}

// MARK: - Mapping Comic <-> CKRecord -----------------------------------------

private extension Persistence {

    func apply(comic: Comic, to record: CKRecord) {
        record["title"]            = comic.title as CKRecordValue
        record["issueNumber"]      = (comic.issueNumber ?? 0) as CKRecordValue
        record["publisher"]        = (comic.publisher ?? "") as CKRecordValue
        record["variant"]          = (comic.variant ?? "") as CKRecordValue
        record["grade"]            = (comic.grade ?? "") as CKRecordValue
        record["coverPrice"]       = (comic.coverPrice ?? 0) as CKRecordValue
        record["currentValue"]     = (comic.currentValue ?? 0) as CKRecordValue
        record["lastValueUpdate"]  = (comic.lastValueUpdate ?? Date(timeIntervalSince1970: 0)) as CKRecordValue
        record["barcode"]          = (comic.barcode ?? "") as CKRecordValue
        record["notes"]            = (comic.notes ?? "") as CKRecordValue
        record["createdAt"]        = comic.createdAt as CKRecordValue
        record["storageLocation"]  = (comic.storageLocation ?? "") as CKRecordValue
        record["volume"]           = (comic.volume ?? 0) as CKRecordValue
        record["year"]             = (comic.year ?? 0) as CKRecordValue
        record["firstAppearanceOf"] = (comic.firstAppearanceOf ?? "") as CKRecordValue
        record["cameoOf"]           = (comic.cameoOf ?? "") as CKRecordValue
        record["variantNotes"]      = (comic.variantNotes ?? "") as CKRecordValue

        // Serialize enums & arrays as JSON Data (portable)
        record["keyFlagsJSON"] = jsonDataValue(encodeKeyFlags(comic.keyFlags))
        record["storyTagsJSON"] = jsonDataValue(comic.storylineTags)

        // Optional thumbnail to keep CloudKit usage low
        #if canImport(UIKit)
        if let data = comic.imageData,
           let thumb = makeThumbnailJPEG(fromJPEGorPNG: data, maxSize: 512) {
            record["thumbnail"] = ckAsset(from: thumb, suggestedName: "\(comic.id.uuidString).jpg")
        } else {
            record["thumbnail"] = nil
        }
        #endif
    }

    func comic(from record: CKRecord) -> Comic? {
        guard let title = record["title"] as? String else { return nil }

        var c = Comic(title: title)
        c.id = UUID(uuidString: record.recordID.recordName) ?? UUID()

        c.issueNumber       = intOrNil(record["issueNumber"])
        c.publisher         = stringOrNil(record["publisher"])
        c.variant           = stringOrNil(record["variant"])
        c.grade             = stringOrNil(record["grade"])
        c.coverPrice        = doubleOrNil(record["coverPrice"])
        c.currentValue      = doubleOrNil(record["currentValue"])
        c.lastValueUpdate   = record["lastValueUpdate"] as? Date
        c.barcode           = stringOrNil(record["barcode"])
        c.notes             = stringOrNil(record["notes"])
        c.createdAt         = (record["createdAt"] as? Date) ?? Date()
        c.storageLocation   = stringOrNil(record["storageLocation"])
        c.volume            = intOrNil(record["volume"])
        c.year              = intOrNil(record["year"])
        c.firstAppearanceOf = stringOrNil(record["firstAppearanceOf"])
        c.cameoOf           = stringOrNil(record["cameoOf"])
        c.variantNotes      = stringOrNil(record["variantNotes"])

        if let keyJSON = record["keyFlagsJSON"] as? Data {
            c.keyFlags = decodeKeyFlags(from: keyJSON)
        }
        if let tagsJSON = record["storyTagsJSON"] as? Data {
            c.storylineTags = decodeStrings(from: tagsJSON)
        }
        return c
    }
}

// MARK: - Merge Policy --------------------------------------------------------

private extension Persistence {
    /// If IDs match, prefer the record with the newer "signal" date.
    /// Include any remote records not present locally.
    func merge(local: [Comic], remote: [Comic]) -> [Comic] {
        var byID: [UUID: Comic] = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })

        for r in remote {
            if let l = byID[r.id] {
                let lDate = l.lastValueUpdate ?? l.createdAt
                let rDate = r.lastValueUpdate ?? r.createdAt
                if rDate > lDate {
                    var merged = r
                    merged.imageData = l.imageData ?? r.imageData
                    byID[r.id] = merged
                }
            } else {
                byID[r.id] = r
            }
        }
        return Array(byID.values)
    }
}

// MARK: - Helpers (types)

private extension Persistence {
    func stringOrNil(_ v: CKRecordValue?) -> String? {
        guard let s = v as? String, !s.isEmpty else { return nil }
        return s
    }
    func intOrNil(_ v: CKRecordValue?) -> Int? {
        guard let n = v as? Int, n != 0 else { return nil }
        return n
    }
    func doubleOrNil(_ v: CKRecordValue?) -> Double? {
        guard let d = v as? Double, d != 0 else { return nil }
        return d
    }

    func jsonDataValue<T: Encodable>(_ value: T?) -> CKRecordValue? {
        guard let value else { return nil }
        if let data = try? JSONEncoder().encode(value) {
            return data as CKRecordValue
        }
        return nil
    }

    func encodeKeyFlags(_ flags: [KeyFlag]?) -> [String]? {
        guard let flags else { return nil }
        return flags.map { $0.rawValue }
    }

    func decodeKeyFlags(from data: Data) -> [KeyFlag]? {
        guard let arr = try? JSONDecoder().decode([String].self, from: data) else { return nil }
        return arr.compactMap { KeyFlag(rawValue: $0) }
    }

    func decodeStrings(from data: Data) -> [String]? {
        try? JSONDecoder().decode([String].self, from: data)
    }
}

// MARK: - Thumbnail helpers (optional, compact) ------------------------------

#if canImport(UIKit)
private extension Persistence {
    /// Creates a JPEG thumbnail of max dimension, quality ~0.8. Returns Data.
    func makeThumbnailJPEG(fromJPEGorPNG data: Data, maxSize: CGFloat) -> Data? {
        guard let img = UIImage(data: data) else { return nil }
        let size = img.size
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = min(1.0, maxSize / max(size.width, size.height))
        let outSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))

        UIGraphicsBeginImageContextWithOptions(outSize, true, 1.0)
        img.draw(in: CGRect(origin: .zero, size: outSize))
        let thumb = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return thumb?.jpegData(compressionQuality: 0.8)
    }

    func ckAsset(from data: Data, suggestedName: String) -> CKAsset? {
        let ext = (suggestedName as NSString).pathExtension
        let finalExt = ext.isEmpty ? "bin" : ext
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(finalExt)
        do {
            try data.write(to: tmpURL, options: .atomic)
            return CKAsset(fileURL: tmpURL)
        } catch { return nil }
    }
}
#endif
#endif // USE_CLOUDSYNC
