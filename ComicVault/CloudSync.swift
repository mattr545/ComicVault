//
//  CloudSync.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: High-level façade around CloudKit sync behaviors for use in SwiftUI.
//

import Foundation
import Combine

// MARK: - Notifications (always available)

extension Notification.Name {
    /// Posted with `object` as `Bool` whenever CloudSync toggles syncing on/off.
    static let cloudSyncIsSyncingChanged = Notification.Name("cloudSyncIsSyncingChanged")
}

#if USE_CLOUDSYNC

import CloudKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Protocol (real CloudKit mode)

@MainActor
protocol CloudSyncing: ObservableObject {
    var accountStatus: CKAccountStatus { get set }
    func refreshAccountStatus() async
    func ensureZone() async
    func pullRemoteChanges(into vm: CollectionViewModel) async
    func pushLocalChanges(from vm: CollectionViewModel) async
    func upsert(_ comic: Comic) async
    func delete(id: UUID) async
}

// MARK: - No-op fallback (when toggle is off)

@MainActor
final class NoCloudSync: ObservableObject, CloudSyncing {
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine

    func refreshAccountStatus() async {}
    func ensureZone() async {}
    func pullRemoteChanges(into vm: CollectionViewModel) async {}
    func pushLocalChanges(from vm: CollectionViewModel) async {}
    func upsert(_ comic: Comic) async {}
    func delete(id: UUID) async {}
}

// MARK: - CloudSync (real CloudKit implementation)

@MainActor
final class CloudSync: ObservableObject, CloudSyncing {

    // MARK: Singleton (concrete)
    static let shared = CloudSync(container: CKContainer.default())

    /// Optional toggle-aware accessor: returns either the real CloudSync or a no-op implementation.
    @MainActor
    static func current() -> any CloudSyncing {
        UserDefaults.standard.bool(forKey: "useCloudSync") ? Self.shared : NoCloudSync()
    }

    // MARK: - Observable status for Settings/UI
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published var isSyncing: Bool = false

    // MARK: - CloudKit wiring
    private let container: CKContainer
    private let database: CKDatabase
    private let zoneID   = CKRecordZone.ID(zoneName: "Comics", ownerName: CKCurrentUserDefaultName)

    // MARK: - Flags / Keys
    private let hasCreatedZoneKey = "icloud.zone.comics.created"
    private let lastPullAtKey     = "icloud.lastPullAt"

    private init(container: CKContainer = .default()) {
        self.container = container
        self.database  = container.privateCloudDatabase
    }

    // Small helper to keep the notification contract consistent
    private func setSyncing(_ newValue: Bool) {
        isSyncing = newValue
        NotificationCenter.default.post(name: .cloudSyncIsSyncingChanged, object: newValue)
    }

    // MARK: - Public status helpers

    func lastPullDate() -> Date? {
        let t = UserDefaults.standard.double(forKey: lastPullAtKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    func refreshAccountStatus() async {
        do {
            accountStatus = try await container.accountStatus()
        } catch {
            accountStatus = .couldNotDetermine
        }
    }

    // MARK: - Zone bootstrap

    func ensureZone() async {
        if UserDefaults.standard.bool(forKey: hasCreatedZoneKey) { return }
        do {
            let zone = CKRecordZone(zoneID: zoneID)
            _ = try await database.save(zone)
            UserDefaults.standard.set(true, forKey: hasCreatedZoneKey)
        } catch {
            // Zone may already exist — mark flag so we don’t loop.
            UserDefaults.standard.set(true, forKey: hasCreatedZoneKey)
        }
    }

    // MARK: - Pull

    func pullRemoteChanges(into vm: CollectionViewModel) async {
        await ensureZone()
        setSyncing(true)
        defer { setSyncing(false) }

        let predicate = NSPredicate(value: true)
        let query     = CKQuery(recordType: "Comic", predicate: predicate)

        var fetched: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        do {
            let result = try await database.records(matching: query, inZoneWith: zoneID)
            fetched.append(contentsOf: result.matchResults.compactMap { _, res in
                if case .success(let r) = res { return r }
                return nil
            })
            cursor = result.queryCursor

            while let cur = cursor {
                let page = try await database.records(continuingMatchFrom: cur)
                fetched.append(contentsOf: page.matchResults.compactMap { _, res in
                    if case .success(let r) = res { return r }
                    return nil
                })
                cursor = page.queryCursor
            }
        } catch {
            #if DEBUG
            print("CloudSync pull error:", error)
            #endif
            return
        }

        let remoteComics = fetched.compactMap { Self.comic(from: $0) }

        // Merge: last-writer-wins using updated stamp
        var local = vm.comics
        for r in remoteComics {
            if let idx = local.firstIndex(where: { $0.id == r.id }) {
                let localStamp  = Self.updatedStamp(for: local[idx])
                let remoteStamp = Self.updatedStamp(for: r)
                if remoteStamp >= localStamp {
                    local[idx] = r
                }
            } else {
                local.append(r)
            }
        }

        vm.comics = local
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastPullAtKey)
    }

    // MARK: - Push single record

    func upsert(_ comic: Comic) async {
        await ensureZone()
        setSyncing(true)
        defer { setSyncing(false) }

        let recordID = CKRecord.ID(recordName: comic.id.uuidString, zoneID: zoneID)
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            record = CKRecord(recordType: "Comic", recordID: recordID)
        }

        Self.apply(comic: comic, to: record)
        record["updatedAt"] = Date() as CKRecordValue

        if let data = comic.imageData,
           let assetURL = Self.makeJPEGAssetURL(from: data) {
            record["cover"] = CKAsset(fileURL: assetURL)
        } else {
            record["cover"] = nil
        }

        do {
            _ = try await database.save(record)
        } catch {
            #if DEBUG
            print("CloudSync upsert error:", error)
            #endif
        }
    }

    // MARK: - Delete single record

    func delete(id: UUID) async {
        await ensureZone()
        setSyncing(true)
        defer { setSyncing(false) }

        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        do {
            _ = try await database.deleteRecord(withID: recordID)
        } catch {
            #if DEBUG
            print("CloudSync delete error:", error)
            #endif
        }
    }

    // MARK: - Bulk push

    func pushLocalChanges(from vm: CollectionViewModel) async {
        await ensureZone()
        setSyncing(true)
        defer { setSyncing(false) }

        var records: [CKRecord] = []
        records.reserveCapacity(vm.comics.count)

        for comic in vm.comics {
            let recordID = CKRecord.ID(recordName: comic.id.uuidString, zoneID: zoneID)
            let record: CKRecord
            do {
                record = try await database.record(for: recordID)
            } catch {
                record = CKRecord(recordType: "Comic", recordID: recordID)
            }

            Self.apply(comic: comic, to: record)
            record["updatedAt"] = Date() as CKRecordValue

            if let data = comic.imageData,
               let assetURL = Self.makeJPEGAssetURL(from: data) {
                record["cover"] = CKAsset(fileURL: assetURL)
            } else {
                record["cover"] = nil
            }

            records.append(record)
        }

        let batchSize = 100
        var start = 0
        while start < records.count {
            let end = min(start + batchSize, records.count)
            let slice = Array(records[start..<end])
            do {
                _ = try await database.modifyRecords(saving: slice, deleting: [])
            } catch {
                #if DEBUG
                print("CloudSync push batch error:", error)
                #endif
            }
            start = end
        }
    }
}

// MARK: - Mapping Comic <-> CKRecord

@MainActor
private extension CloudSync {
    static func updatedStamp(for comic: Comic) -> Date {
        if let d = comic.lastValueUpdate { return d }
        return comic.createdAt
    }

    static func comic(from r: CKRecord) -> Comic? {
        guard let id = UUID(uuidString: r.recordID.recordName) else { return nil }
        guard let title = r["title"] as? String, !title.isEmpty else { return nil }

        var c = Comic(title: title)
        c.id              = id
        c.issueNumber     = r["issueNumber"] as? Int
        c.publisher       = r["publisher"] as? String
        c.variant         = r["variant"] as? String
        c.grade           = r["grade"] as? String
        c.coverPrice      = r["coverPrice"] as? Double
        c.currentValue    = r["currentValue"] as? Double
        c.lastValueUpdate = r["lastValueUpdate"] as? Date
        c.barcode         = r["barcode"] as? String
        c.notes           = r["notes"] as? String
        c.createdAt       = (r["createdAt"] as? Date) ?? Date()
        c.storageLocation = r["storageLocation"] as? String
        c.volume          = r["volume"] as? Int
        c.year            = r["year"] as? Int

        if let rawFlags = r["keyFlags"] as? [String] {
            c.keyFlags = rawFlags.compactMap { KeyFlag(rawValue: $0) }
        }
        c.firstAppearanceOf = r["firstAppearanceOf"] as? String
        c.cameoOf           = r["cameoOf"] as? String
        c.storylineTags     = r["storylineTags"] as? [String]
        c.variantNotes      = r["variantNotes"] as? String

        return c
    }

    static func apply(comic: Comic, to r: CKRecord) {
        r["title"]           = comic.title as CKRecordValue
        r["issueNumber"]     = comic.issueNumber as CKRecordValue?
        r["publisher"]       = comic.publisher as CKRecordValue?
        r["variant"]         = comic.variant as CKRecordValue?
        r["grade"]           = comic.grade as CKRecordValue?
        r["coverPrice"]      = comic.coverPrice as CKRecordValue?
        r["currentValue"]    = comic.currentValue as CKRecordValue?
        r["lastValueUpdate"] = comic.lastValueUpdate as CKRecordValue?
        r["barcode"]         = comic.barcode as CKRecordValue?
        r["notes"]           = comic.notes as CKRecordValue?
        r["createdAt"]       = comic.createdAt as CKRecordValue
        r["storageLocation"] = comic.storageLocation as CKRecordValue?
        r["volume"]          = comic.volume as CKRecordValue?
        r["year"]            = comic.year as CKRecordValue?

        if let flags = comic.keyFlags?.map(\.rawValue) {
            r["keyFlags"] = flags as CKRecordValue
        } else {
            r["keyFlags"] = nil
        }
        r["firstAppearanceOf"] = comic.firstAppearanceOf as CKRecordValue?
        r["cameoOf"]           = comic.cameoOf as CKRecordValue?
        r["storylineTags"]     = comic.storylineTags as CKRecordValue?
        r["variantNotes"]      = comic.variantNotes as CKRecordValue?
    }
}

// MARK: - JPEG Asset helper

@MainActor
private extension CloudSync {
    static func makeJPEGAssetURL(
        from data: Data,
        maxDimension: CGFloat = 2000,
        maxBytes: Int = 3_000_000
    ) -> URL? {
        #if canImport(UIKit)
        guard let img = UIImage(data: data) else { return nil }

        let targetSize = resizedSize(for: img.size, maxDimension: maxDimension)
        let scaled = (targetSize == img.size) ? img : redraw(img, to: targetSize)

        for q in [0.8, 0.7, 0.6, 0.5, 0.4] as [CGFloat] {
            if let jpeg = scaled.jpegData(compressionQuality: q),
               jpeg.count <= maxBytes {
                return writeTemp(jpeg)
            }
        }

        if let jpeg = scaled.jpegData(compressionQuality: 0.4) {
            return writeTemp(jpeg)
        }
        return nil
        #else
        return nil
        #endif
    }

    static func resizedSize(for s: CGSize, maxDimension: CGFloat) -> CGSize {
        let longest = max(s.width, s.height)
        guard longest > maxDimension, longest > 0 else { return s }
        let scale = maxDimension / longest
        return CGSize(width: floor(s.width * scale), height: floor(s.height * scale))
    }

    #if canImport(UIKit)
    static func redraw(_ image: UIImage, to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    #endif

    static func writeTemp(_ data: Data) -> URL? {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Tiny global accessor (optional)

@MainActor
func cloudSync() -> any CloudSyncing { CloudSync.shared }

#else // !USE_CLOUDSYNC

// MARK: - Local-only shim (no CloudKit dependency)

@MainActor
final class CloudSync: ObservableObject {

    static let shared = CloudSync()

    @MainActor
    static func current() -> CloudSync { shared }

    @Published var isSyncing: Bool = false

    func lastPullDate() -> Date? { nil }

    func refreshAccountStatus() async {}
    func ensureZone() async {}
    func pullRemoteChanges(into vm: CollectionViewModel) async {}
    func pushLocalChanges(from vm: CollectionViewModel) async {}
    func upsert(_ comic: Comic) async {}
    func delete(id: UUID) async {}
}

#endif // USE_CLOUDSYNC
