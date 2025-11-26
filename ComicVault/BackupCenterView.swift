//
//  BackupCenterView.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: UI hub for export/import backups (CSV, snapshots, etc.).
//
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct BackupCenterView: View {
    @EnvironmentObject private var collectionVM: CollectionViewModel
    private let backup = BackupManager.shared

    @State private var isExporting = false
    @State private var exportURL: URL?

    var body: some View {
        List {
            Section(header: Text("Status")) {
                HStack {
                    Label("Last Backup", systemImage: "clock")
                    Spacer()
                    Text(lastBackupText())
                        .foregroundStyle(.secondary)
                }
                if let msg = backup.errorMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section(header: Text("Export")) {
                Button {
                    Task { await runJSONExport() }
                } label: {
                    Label("Export JSON", systemImage: "square.and.arrow.up")
                }
                .disabled(isExporting)

                Button {
                    Task { await runCSVExport() }
                } label: {
                    Label("Export CSV", systemImage: "tablecells")
                }
                .disabled(isExporting)
            }
        }
        .navigationTitle("Backups")
        .fileExporter(
            isPresented: Binding(
                get: { exportURL != nil },
                set: { if !$0 { exportURL = nil } }
            ),
            document: exportURL.map { TemporaryFileDocument(url: $0) },
            contentType: .data,
            defaultFilename: exportURL.map { $0.deletingPathExtension().lastPathComponent } ?? "ComicVault-Backup"
        ) { _ in
            // Nothing extra. TemporaryFileDocument handles the export wrapper.
        }
    }

    // MARK: - Helpers

    private func lastBackupText() -> String {
        guard let d = backup.lastBackupDate else { return "—" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }

    private func runJSONExport() async {
        isExporting = true
        defer { isExporting = false }
        exportURL = await backup.exportJSON(comics: collectionVM.comics)
    }

    private func runCSVExport() async {
        isExporting = true
        defer { isExporting = false }
        exportURL = await backup.exportCSV(comics: collectionVM.comics)
    }
}

// MARK: - TemporaryFileDocument

private struct TemporaryFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    let url: URL

    init(url: URL) { self.url = url }

    // We do not support reading. This document only wraps an existing temp file for export.
    init(configuration: ReadConfiguration) throws {
        // Use the canonical "feature unsupported" error. This is present across SDKs.
        throw NSError(
            domain: NSCocoaErrorDomain,
            code: NSFeatureUnsupportedError,
            userInfo: nil
        )
        // If you prefer Swift's typed error and your SDK supports it, you could use:
        // throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: url, options: .immediate)
    }
}
