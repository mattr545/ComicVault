//
//  ComicsDocument.swift
//  ComicVault
//
//  File created on 10/15/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Document wrapper used for exporting/importing collections as files.
//
//  Running Edit Log
//  - Reformatted and annotated on 10/19/25.
//

import SwiftUI
import UniformTypeIdentifiers


// === STRUCT: ComicsDocument: ===
// STRUCT `ComicsDocument:`: A data type or view that groups related fields/logic.
// This block defines how `ComicsDocument:` behaves and is used throughout the app.
struct ComicsDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.json]

    var comics: [Comic]

    init(comics: [Comic]) {
        self.comics = comics
    }

    // Read from a file (import)
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.comics = try JSONDecoder().decode([Comic].self, from: data)
    }

    // Write to a file (export)
// MARK: - Function: fileWrapper
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(comics)
        return .init(regularFileWithContents: data)
    }
}
