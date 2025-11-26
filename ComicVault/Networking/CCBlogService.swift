//
//  CCBlogService.swift
//  ComicVault
//
//  File created on 11/25/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Fetches public CryptoComics blog posts for display in ComicVault.
//  Note: Does NOT require user login; uses a public, read-only endpoint.
//

import Foundation

@MainActor
final class CCBlogStore: ObservableObject {
    @Published var posts: [CCBlogPost] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let session: URLSession
    private let decoder: JSONDecoder

    // TODO: Replace this with the real CryptoComics blog API endpoint.
    private let endpoint = URL(string: "https://cryptocomics.com/api/blog")!

    init(session: URLSession = .shared) {
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            let (data, response) = try await session.data(from: endpoint)

            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let posts = try decoder.decode([CCBlogPost].self, from: data)
            self.posts = posts
        } catch {
            self.errorMessage = "Couldn’t load the CryptoComics blog right now."
        }

        isLoading = false
    }
}
