//
//  CCService.swift
//  ComicVault
//
//  File created on 11/25/25 by ApogeeINVENT, a software engineering company,
//  in collaboration with the CryptoComics team.
//
//  Description:
//  Networking client for the CryptoComics API.
//  Sends POST form-data commands and decodes responses.
//

import Foundation

final class CCService {

    static let shared = CCService()

    private init() {}

    private let endpoint = URL(string: "https://cryptocomics.com/service")!

    // MARK: - Core request

    func sendCommand(
        command: String,
        auth: CCAuth,
        extras: [String: String] = [:]
    ) async throws -> CCResponse {

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = auth.asParams(command: command, extras: extras)
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(CCResponse.self, from: data)
    }

    // MARK: - Example: Fetch owned comics (you will wire in the real command)

    func fetchOwnedComics(auth: CCAuth) async throws -> [CCRemoteComic] {
        let response = try await sendCommand(
            command: "get_orders",        // Placeholder: will update after CC provides the correct one
            auth: auth
        )

        guard response.status == 0 else {
            throw NSError(domain: "CryptoComics", code: response.status, userInfo: [
                NSLocalizedDescriptionKey: response.statusMessage ?? "Unknown error"
            ])
        }

        // When CC gives us the real structure, decode properly here
        // For now, a simple placeholder:
        let comics: [CCRemoteComic] = [
            CCRemoteComic(id: "example-1", title: "DreamKeepers Vol. 5", issue: nil, series: "DreamKeepers", coverURL: nil)
        ]

        return comics
    }
}
