//
//  CloudKitSchema.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Defines CloudKit record types, keys, and schema helpers for ComicVault syncing.
//

import Foundation

/// Record type used in CloudKit (private database).
let CKComicRecordType = "Comic"

/// Field keys inside the CKRecord; keep these stable once shipped.
enum CKComicKey {
    static let id               = "id"              // String (UUID uuidString)
    static let title            = "title"           // String
    static let issueNumber      = "issueNumber"     // Int (nullable)
    static let publisher        = "publisher"       // String (nullable)
    static let variant          = "variant"         // String (nullable)
    static let grade            = "grade"           // String (nullable)
    static let coverPrice       = "coverPrice"      // Double (nullable)
    static let currentValue     = "currentValue"    // Double (nullable)
    static let lastValueUpdate  = "lastValueUpdate" // Date (nullable)
    static let barcode          = "barcode"         // String (nullable)
    static let notes            = "notes"           // String (nullable)
    static let createdAt        = "createdAt"       // Date
    static let storageLocation  = "storageLocation" // String (nullable)
    static let volume           = "volume"          // Int (nullable)
    static let year             = "year"            // Int (nullable)
    static let keyFlags         = "keyFlags"        // [String] (nullable)
    static let firstAppearance  = "firstAppearance" // String (nullable)
    static let cameoOf          = "cameoOf"         // String (nullable)
    static let storylineTags    = "storylineTags"   // [String] (nullable)
    static let variantNotes     = "variantNotes"    // String (nullable)
    static let modifiedAt       = "modifiedAt"      // Date
    // NOTE: We are intentionally NOT syncing imageData/extraImages in v1.0
}

#if USE_CLOUDSYNC
import CloudKit

/// Minimal mapper between our `Comic` model and CKRecord.
/// v1.0 deliberately excludes image payloads (large), which we’ll add later using CKAsset(s).
enum CKComicMapper {

    /// Create a stable CKRecord.ID derived from Comic.id to avoid duplicates.
    static func recordID(for comicID: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: comicID.uuidString)
    }

    static func toRecord(_ comic: Comic, in zoneID: CKRecordZone.ID? = nil) -> CKRecord {
        let rid = recordID(for: comic.id)
        let rec = CKRecord(recordType: CKComicRecordType, recordID: rid)

        rec[CKComicKey.id]              = comic.id.uuidString as CKRecordValue
        rec[CKComicKey.title]           = comic.title as CKRecordValue
        if let n = comic.issueNumber { rec[CKComicKey.issueNumber] = n as CKRecordValue }
        if let p = comic.publisher { rec[CKComicKey.publisher] = p as CKRecordValue }
        if let v = comic.variant { rec[CKComicKey.variant] = v as CKRecordValue }
        if let g = comic.grade { rec[CKComicKey.grade] = g as CKRecordValue }
        if let cp = comic.coverPrice { rec[CKComicKey.coverPrice] = cp as CKRecordValue }
        if let cv = comic.currentValue { rec[CKComicKey.currentValue] = cv as CKRecordValue }
        if let lvu = comic.lastValueUpdate { rec[CKComicKey.lastValueUpdate] = lvu as CKRecordValue }
        if let bc = comic.barcode { rec[CKComicKey.barcode] = bc as CKRecordValue }
        if let nt = comic.notes { rec[CKComicKey.notes] = nt as CKRecordValue }
        rec[CKComicKey.createdAt]       = comic.createdAt as CKRecordValue
        if let sl = comic.storageLocation { rec[CKComicKey.storageLocation] = sl as CKRecordValue }
        if let vol = comic.volume { rec[CKComicKey.volume] = vol as CKRecordValue }
        if let yr = comic.year { rec[CKComicKey.year] = yr as CKRecordValue }
        if let flags = comic.keyFlags?.map({ $0.rawValue }), !flags.isEmpty {
            rec[CKComicKey.keyFlags] = flags as CKRecordValue
        }
        if let first = comic.firstAppearanceOf { rec[CKComicKey.firstAppearance] = first as CKRecordValue }
        if let cameo = comic.cameoOf { rec[CKComicKey.cameoOf] = cameo as CKRecordValue }
        if let tags = comic.storylineTags, !tags.isEmpty {
            rec[CKComicKey.storylineTags] = tags as CKRecordValue
        }
        if let vn = comic.variantNotes { rec[CKComicKey.variantNotes] = vn as CKRecordValue }

        rec[CKComicKey.modifiedAt]      = comic.modifiedAt as CKRecordValue

        return rec
    }

    static func toComic(_ rec: CKRecord) -> Comic? {
        guard
            let idStr = rec[CKComicKey.id] as? String,
            let uuid  = UUID(uuidString: idStr),
            let title = rec[CKComicKey.title] as? String,
            let createdAt = rec[CKComicKey.createdAt] as? Date
        else { return nil }

        var c = Comic(title: title)
        c.id              = uuid
        c.issueNumber     = rec[CKComicKey.issueNumber] as? Int
        c.publisher       = rec[CKComicKey.publisher] as? String
        c.variant         = rec[CKComicKey.variant] as? String
        c.grade           = rec[CKComicKey.grade] as? String
        c.coverPrice      = rec[CKComicKey.coverPrice] as? Double
        c.currentValue    = rec[CKComicKey.currentValue] as? Double
        c.lastValueUpdate = rec[CKComicKey.lastValueUpdate] as? Date
        c.barcode         = rec[CKComicKey.barcode] as? String
        c.notes           = rec[CKComicKey.notes] as? String
        c.createdAt       = createdAt
        c.storageLocation = rec[CKComicKey.storageLocation] as? String
        c.volume          = rec[CKComicKey.volume] as? Int
        c.year            = rec[CKComicKey.year] as? Int
        if let rawFlags = rec[CKComicKey.keyFlags] as? [String] {
            c.keyFlags = rawFlags.compactMap { KeyFlag(rawValue: $0) }
        }
        c.firstAppearanceOf = rec[CKComicKey.firstAppearance] as? String
        c.cameoOf           = rec[CKComicKey.cameoOf] as? String
        c.storylineTags     = rec[CKComicKey.storylineTags] as? [String]
        c.variantNotes      = rec[CKComicKey.variantNotes] as? String
        c.modifiedAt        = (rec[CKComicKey.modifiedAt] as? Date) ?? rec.modificationDate ?? Date()

        // v1.0: imageData / extraImages intentionally excluded from Cloud sync.
        return c
    }
}
#endif
