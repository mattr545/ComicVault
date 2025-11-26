//
//  ComicDetailEditIntegration.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Bridges ComicDetailView with the edit flows and value/history updates.
//

import SwiftUI

struct ComicEditToolbar: ViewModifier {
    @EnvironmentObject private var vm: CollectionViewModel
    @Environment(\.dismiss) private var dismiss

    let comic: Comic

    @State private var showEdit = false
    @State private var confirmDelete = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit", systemImage: "pencil") { showEdit = true }
                        Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showEdit) {
                NavigationView {
                    EditComicView(comic: comic) { updated in
                        // If your VM has a replace helper, call it here instead.
                        if let idx = vm.comics.firstIndex(where: { $0.id == updated.id }) {
                            vm.comics[idx] = updated
                        }
                    }
                }
            }
            .alert("Delete this comic?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) {
                    // If your VM has a delete helper, call it here instead.
                    if let idx = vm.comics.firstIndex(where: { $0.id == comic.id }) {
                        vm.comics.remove(at: idx)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This cannot be undone.")
            }
    }
}

extension View {
    /// Attach edit/delete actions to a comic detail screen.
    func withEditActions(for comic: Comic) -> some View {
        modifier(ComicEditToolbar(comic: comic))
    }
}
