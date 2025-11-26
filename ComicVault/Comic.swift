//
//  Comic.swift
//  ComicVault
//
//  File created on 10/15/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Core Comic model used for collection, wishlist, metadata, and sync.
//
//  Running Edit Log
//  - 11-04-25: Added modifiedAt for CloudKit LWW.
//  - 11-08-25: Added wishlistTargetPrice and header normalization.
//
//

import Foundation

// MARK: - Key flags

enum KeyFlag: String, Codable, CaseIterable, Hashable {
    case firstAppearance
    case origin
    case death
    case cameo
    case majorEvent
    case iconicCover
    case errorPrint
    case newsstand
    case direct
    case retailerIncentive
    case signed
}

// MARK: - Comic model

struct Comic: Identifiable, Codable {
    // Identity
    var id = UUID()

    // Core
    var title: String
    var issueNumber: Int?
    var publisher: String?

    // Artwork (not synced in v1 CloudKit)
    var imageData: Data?
    var variant: String?

    // Value
    var grade: String?
    var coverPrice: Double?
    var currentValue: Double?
    var lastValueUpdate: Date? = nil

    // Metadata
    var barcode: String?
    var notes: String?
    var createdAt: Date = Date()

    // Storage aliasing (persisted as key string)
    var storageLocation: String?
    var storage: String? {
        get { storageLocation }
        set { storageLocation = newValue }
    }

    // Keys & Variants
    var volume: Int?                       // e.g., Volume 2
    var year: Int?                         // publication year (yyyy)
    var keyFlags: [KeyFlag]?               // selected flags
    var firstAppearanceOf: String?         // character/team
    var cameoOf: String?                   // character/team (cameo only)
    var storylineTags: [String]?           // arc/event tags
    var variantNotes: String?              // notes like "2nd print foil", "store exclusive"

    // Supplemental photos (legacy field; still supported)
    var extraImages: [Data]? = nil

    // Grading helper & defect photos (local-only hints)
    var defectPhotos: [DefectPhoto]? = nil
    var conditionChecklist: ConditionChecklist? = nil
    var suggestedGradeRange: GradeSuggestion? = nil
    var gradeFloorValueHint: Double? = nil
    var gradeCeilingValueHint: Double? = nil
    var gradeHintSource: String? = nil

    // Wishlist / Watchlist
    var wishlistTargetPrice: Double? = nil

    // Sync/conflict
    var modifiedAt: Date = Date()

    // Handy display helper
    var displayTitle: String {
        var base = title
        if let issue = issueNumber { base += " #\(issue)" }
        if let v = variant, !v.isEmpty { base += " (\(v))" }
        return base
    }

    // Convenience
    var hasDefectPhotos: Bool {
        guard let photos = defectPhotos else { return false }
        return !photos.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case issueNumber
        case publisher
        case imageData
        case variant
        case grade
        case coverPrice
        case currentValue
        case lastValueUpdate
        case barcode
        case notes
        case createdAt
        case storageLocation

        case volume
        case year
        case keyFlags
        case firstAppearanceOf
        case cameoOf
        case storylineTags
        case variantNotes

        case extraImages

        case defectPhotos
        case conditionChecklist
        case suggestedGradeRange
        case gradeFloorValueHint
        case gradeCeilingValueHint
        case gradeHintSource

        case wishlistTargetPrice
        case modifiedAt
    }
}

// MARK: - Demo Sample

extension Comic {
    static var sample: Comic {
        Comic(
            title: "The Amazing Spider-Man",
            issueNumber: 300,
            publisher: "Marvel",
            imageData: nil,
            variant: "Todd McFarlane Variant",
            grade: "9.8 NM/M",
            coverPrice: 1.50,
            currentValue: 3_500.00,
            lastValueUpdate: Date(),
            barcode: "759606024575300",
            notes: "First full appearance of Venom.",
            createdAt: Date(),
            storageLocation: "ON_DISPLAY",
            volume: 1,
            year: 1988,
            keyFlags: [.firstAppearance, .iconicCover, .majorEvent],
            firstAppearanceOf: "Venom (Eddie Brock)",
            cameoOf: nil,
            storylineTags: ["Venom Saga"],
            variantNotes: "Newsstand",
            extraImages: nil,
            defectPhotos: nil,
            conditionChecklist: nil,
            suggestedGradeRange: nil,
            gradeFloorValueHint: nil,
            gradeCeilingValueHint: nil,
            gradeHintSource: nil,
            wishlistTargetPrice: nil,
            modifiedAt: Date()
        )
    }
}
