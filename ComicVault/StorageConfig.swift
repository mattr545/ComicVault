//
//  StorageConfig.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Storage location presets and helper labels for comics.
//
//  Running Edit Log
//  - 10/22/25: Persists long/short box counts (0…200).
//              - Builds UI options (“Long Box #7”, “Short Box #2”, etc.).
//              - Encodes/decodes storage selection to/from Comic.storageLocation.
//              - Normalizes comics when counts shrink (out-of-range -> Not Stored).
//

import Foundation

/// UI model used for pickers etc.
enum StorageSlot: Hashable {
    case notStored
    case display
    case long(Int)   // 1-based index
    case short(Int)  // 1-based index
}

enum StorageConfig {
    // UserDefaults keys
    private static let longKey  = "storage.longbox.count"
    private static let shortKey = "storage.shortbox.count"

    /// Hard cap to keep UI simple & performant.
    static let maxBoxes = 200

    // MARK: - Counts (0…maxBoxes)

    static var longBoxCount: Int {
        get { clamp(UserDefaults.standard.integer(forKey: longKey)) }
        set { UserDefaults.standard.set(clamp(newValue), forKey: longKey) }
    }

    static var shortBoxCount: Int {
        get { clamp(UserDefaults.standard.integer(forKey: shortKey)) }
        set { UserDefaults.standard.set(clamp(newValue), forKey: shortKey) }
    }

    // MARK: - Options for pickers

    static func options() -> [StorageSlot] {
        var out: [StorageSlot] = [.notStored, .display]
        if longBoxCount > 0 {
            out.append(contentsOf: (1...longBoxCount).map(StorageSlot.long))
        }
        if shortBoxCount > 0 {
            out.append(contentsOf: (1...shortBoxCount).map(StorageSlot.short))
        }
        return out
    }

    static func displayName(for slot: StorageSlot) -> String {
        switch slot {
        case .notStored:  return "Not Stored"
        case .display:    return "On Display"
        case .long(let n):  return "Long Box #\(n)"
        case .short(let n): return "Short Box #\(n)"
        }
    }

    // MARK: - Encoding for persistence (Comic.storageLocation)

    /// Convert a slot to a stable string we store on `Comic.storageLocation`.
    /// - Returns nil for `.notStored`.
    static func key(for slot: StorageSlot) -> String? {
        switch slot {
        case .notStored:     return nil
        case .display:       return "display"
        case .long(let n):   return "long:\(n)"
        case .short(let n):  return "short:\(n)"
        }
    }

    /// Convert a stored key back to a slot. Unknown/malformed -> `.notStored`.
    static func slot(from key: String?) -> StorageSlot {
        guard let key, !key.isEmpty else { return .notStored }
        if key == "display" { return .display }
        if key.hasPrefix("long:"), let n = Int(key.dropFirst(5)), n >= 1 { return .long(n) }
        if key.hasPrefix("short:"), let n = Int(key.dropFirst(6)), n >= 1 { return .short(n) }
        return .notStored
    }

    /// Human label for a stored key (used in details etc.).
    static func label(forStoredKey key: String?) -> String {
        displayName(for: slot(from: key))
    }

    // MARK: - Normalization

    /// If counts were reduced and some comics point to removed boxes,
    /// set those to `.notStored`. Returns number of comics changed.
    static func normalize(comics: inout [Comic]) -> Int {
        var changed = 0
        let maxLong  = longBoxCount
        let maxShort = shortBoxCount

        for i in comics.indices {
            let slot = slot(from: comics[i].storageLocation)

            let needsReset: Bool = {
                switch slot {
                case .long(let n):  return n > maxLong
                case .short(let n): return n > maxShort
                default:            return false
                }
            }()

            if needsReset {
                comics[i].storageLocation = nil // -> Not Stored
                changed += 1
            }
        }
        return changed
    }

    // MARK: - Helpers

    private static func clamp(_ x: Int) -> Int {
        if x < 0 { return 0 }
        if x > maxBoxes { return maxBoxes }
        return x
    }
}
