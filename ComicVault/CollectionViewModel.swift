//
//  CollectionViewModel.swift
//  ComicVault
//
//  File created on 10/15/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Source of truth for owned collection, sync, and value histories.
//
//  Running Edit Log
//  - 11-04-25: Added modifiedAt merge for CloudKit.
//  - 11-07-25: Hooked into PriceAlertManager via addValuePoint.
//              Added CloudSync merge + value history support.
//  - 11-08-25: Header normalization.
//  - 11-09-25: Added local persistence for comics and header normalization.
//
//

import Foundation
import Combine

@MainActor
final class CollectionViewModel: ObservableObject {

    // MARK: - Comics (owned collection)

    /// Owned comics. Changes are:
    /// - auto-persisted to disk (see setupAutoSave/persistComics),
    /// - pushed to Cloud (where applicable) via existing helpers.
    @Published var comics: [Comic] = []

    // MARK: - Sync status

    @Published var syncStatus: SyncStatus = .idle

    // MARK: - Value History (per comic.id)

    @Published private var valueHistories: [UUID: [ValuePoint]] = [:] {
        didSet { persistHistories() }
    }

    // MARK: - Persistence Keys / Files

    private let historiesKey = "value_histories_v1"

    /// Local filesystem storage for the comics array.
    private static let comicsFileName = "collection_comics.json"

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        loadComics()
        loadHistories()
        setupAutoSave()
    }

    // MARK: - Cloud Sync lifecycle

    func beginCloudSync() {
        Task { await refreshFromCloud() }
    }

    func refreshFromCloud() async {
        syncStatus = .syncing
        do {
            let remote = try await CloudSyncManager.shared.fetchAll()
            let merged = mergeLocal(local: comics, remote: remote)
            comics = merged.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            syncStatus = .idle
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - Comic Creation

    func addComic(
        title: String,
        issueNumber: Int?,
        publisher: String?,
        imageData: Data?,
        barcode: String?,
        notes: String?
    ) {
        let new = Comic(
            title: title,
            issueNumber: issueNumber,
            publisher: publisher,
            imageData: imageData,
            variant: nil,
            grade: nil,
            coverPrice: nil,
            currentValue: nil,
            lastValueUpdate: nil,
            barcode: barcode,
            notes: notes,
            createdAt: Date(),
            storageLocation: nil,
            volume: nil,
            year: nil,
            keyFlags: nil,
            firstAppearanceOf: nil,
            cameoOf: nil,
            storylineTags: nil,
            variantNotes: nil,
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

        comics.append(new)

        Task {
            await pushToCloud(new)
        }
    }

    /// Legacy version for older call sites.
    func addComic(
        title: String,
        issueNumber: Int?,
        publisher: String?,
        imageData: Data?,
        notes: String?,
        barcode: String?
    ) {
        addComic(
            title: title,
            issueNumber: issueNumber,
            publisher: publisher,
            imageData: imageData,
            barcode: barcode,
            notes: notes
        )
    }

    // MARK: - Deletes

    func deleteComic(id: UUID) {
        if let idx = comics.firstIndex(where: { $0.id == id }) {
            comics.remove(at: idx)
        }
        Task {
            await deleteFromCloud(id: id)
        }
    }

    // MARK: - Value History API

    func valueHistory(for comicID: UUID) -> [ValuePoint] {
        valueHistories[comicID] ?? []
    }

    func addValuePoint(
        for comicID: UUID,
        value: Double,
        source: ValueSource,
        note: String?
    ) {
        var list = valueHistories[comicID] ?? []

        if let last = list.last,
           last.value == value,
           last.source == source {
            // Avoid duplicating identical trailing points
            return
        }

        let point = ValuePoint(value: value, source: source, note: note)
        list.append(point)
        valueHistories[comicID] = list

        if let idx = comics.firstIndex(where: { $0.id == comicID }) {
            let oldValue = comics[idx].currentValue

            var c = comics[idx]
            c.currentValue    = value
            c.lastValueUpdate = point.date
            c.modifiedAt      = Date()
            comics[idx]       = c

            Task { await pushToCloud(c) }

            // Provider label for alerts when available.
            let providerLabel: String?
            switch source {
            case .manual:
                providerLabel = "Manual"
            case .estimated:
                providerLabel = note
            }

            if #available(iOS 16.0, *) {
                PriceAlertManager.shared.checkAndNotify(
                    comic: c,
                    old: oldValue,
                    new: value,
                    provider: providerLabel
                )
            }
        }
    }

    func removeLastValuePoint(for comicID: UUID) {
        guard var list = valueHistories[comicID], !list.isEmpty else { return }
        _ = list.popLast()
        valueHistories[comicID] = list

        if let idx = comics.firstIndex(where: { $0.id == comicID }) {
            var c = comics[idx]
            if let last = list.last {
                c.currentValue    = last.value
                c.lastValueUpdate = last.date
            } else {
                c.currentValue    = nil
                c.lastValueUpdate = nil
            }
            c.modifiedAt = Date()
            comics[idx]  = c

            Task { await pushToCloud(c) }
        }
    }

    // MARK: - Cloud helpers

    private func pushToCloud(_ comic: Comic) async {
        await setSyncing {
            try await CloudSyncManager.shared.upsert(comic)
        }
    }

    private func deleteFromCloud(id: UUID) async {
        await setSyncing {
            try await CloudSyncManager.shared.delete(id: id)
        }
    }

    private func setSyncing(_ block: @escaping () async throws -> Void) async {
        syncStatus = .syncing
        do {
            try await block()
            syncStatus = .idle
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    private func mergeLocal(local: [Comic], remote: [Comic]) -> [Comic] {
        var byID: [UUID: Comic] = [:]
        for c in local {
            byID[c.id] = c
        }
        for r in remote {
            if let exist = byID[r.id] {
                byID[r.id] = (r.modifiedAt >= exist.modifiedAt) ? r : exist
            } else {
                byID[r.id] = r
            }
        }
        return Array(byID.values)
    }

    // MARK: - Local Persistence: Comics

    /// Where we store the serialized comics array.
    private func comicsFileURL() -> URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        return docs.appendingPathComponent(Self.comicsFileName, isDirectory: false)
    }

    /// Debounced auto-save whenever `comics` changes.
    private func setupAutoSave() {
        $comics
            .dropFirst() // ignore initial assignment
            .debounce(for: .seconds(0.8), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.persistComics()
            }
            .store(in: &cancellables)
    }

    /// Persist comics array to disk as JSON.
    private func persistComics() {
        let url = comicsFileURL()
        do {
            let data = try JSONEncoder().encode(comics)
            try data.write(to: url, options: [.atomic])
        } catch {
            #if DEBUG
            print("Failed to persist comics: \(error)")
            #endif
        }
    }

    /// Load comics array from disk if present.
    private func loadComics() {
        let url = comicsFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            comics = []
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Comic].self, from: data)
            comics = decoded
        } catch {
            #if DEBUG
            print("Failed to load comics: \(error)")
            #endif
            comics = []
        }
    }

    // MARK: - Local Persistence: Value Histories

    private func persistHistories() {
        do {
            let data = try JSONEncoder().encode(EncodableHistories(valueHistories))
            UserDefaults.standard.set(data, forKey: historiesKey)
        } catch {
            // Intentionally ignore; history loss is non-fatal.
        }
    }

    private func loadHistories() {
        guard let data = UserDefaults.standard.data(forKey: historiesKey) else {
            valueHistories = [:]
            return
        }
        do {
            let decoded = try JSONDecoder().decode(EncodableHistories.self, from: data)
            valueHistories = decoded.toDictionary()
        } catch {
            valueHistories = [:]
        }
    }
}

// Conform to the AddComicVM protocol used by AddComicView.
extension CollectionViewModel: AddComicVM { }

// MARK: - Codable helper for [UUID: [ValuePoint]]

private struct EncodableHistories: Codable {
    let items: [String: [ValuePoint]]

    init(_ dict: [UUID: [ValuePoint]]) {
        self.items = Dictionary(uniqueKeysWithValues: dict.map { ($0.key.uuidString, $0.value) })
    }

    func toDictionary() -> [UUID: [ValuePoint]] {
        var out: [UUID: [ValuePoint]] = [:]
        for (k, v) in items {
            if let id = UUID(uuidString: k) {
                out[id] = v
            }
        }
        return out
    }
}

// MARK: - Defect Photo Helpers

extension CollectionViewModel {

    func defectPhotos(for comicID: UUID) -> [DefectPhoto] {
        comics.first(where: { $0.id == comicID })?.defectPhotos ?? []
    }

    func addDefectPhoto(for comicID: UUID, data: Data, label: String?) {
        guard let index = comics.firstIndex(where: { $0.id == comicID }) else { return }

        var comic = comics[index]
        var photos = comic.defectPhotos ?? []

        let photo = DefectPhoto(
            id: UUID(),
            data: data,
            label: label
        )

        photos.append(photo)
        comic.defectPhotos = photos
        comic.modifiedAt = Date()
        comics[index] = comic
    }

    func removeDefectPhoto(for comicID: UUID, photoID: UUID) {
        guard let index = comics.firstIndex(where: { $0.id == comicID }) else { return }

        var comic = comics[index]
        guard var photos = comic.defectPhotos else { return }

        photos.removeAll { $0.id == photoID }
        comic.defectPhotos = photos.isEmpty ? nil : photos
        comic.modifiedAt = Date()
        comics[index] = comic
    }
}

// MARK: - Grading Helpers (used by ComicDetailView)

extension CollectionViewModel {

    /// Apply grading results from the grading wizard to a specific comic.
    @MainActor
    func applyGrading(for comicID: UUID,
                      checklist: ConditionChecklist,
                      suggestion: GradeSuggestion) async {
        guard let index = comics.firstIndex(where: { $0.id == comicID }) else { return }
        var comic = comics[index]

        comic.conditionChecklist   = checklist
        comic.suggestedGradeRange  = suggestion
        comic.modifiedAt           = Date()

        comics[index] = comic
    }
}
