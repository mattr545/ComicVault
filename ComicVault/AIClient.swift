//
//  AIClient.swift
//  ComicVault
//
//  File created on 11/03/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Thin OpenAI client with key storage and health check.
//
//  Running Edit Log
//  - 11-03-25: Initial implementation for chat + model check.
//  - 11-08-25: Header normalization.
//
//

import Foundation

struct AIClient {
    static let shared = AIClient()
    private init() {}

    // Keychain locations (match Settings)
    let service = "com.comicvault.ai.openai"
    let account = "user_api_key"

    // Global enable toggle (user can turn AI off without deleting key)
    private let enabledKey = "ai.enabled"

    // MARK: Status

    var isConfigured: Bool {
        // SecureStore.get returns String (non-optional) in your project.
        // Treat failures as empty string.
        let key = (try? SecureStore.get(service: service, account: account)) ?? ""
        let hasKey = !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasKey && UserDefaults.standard.bool(forKey: enabledKey)
    }

    func enableAI(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: enabledKey)
    }

    func saveUserAPIKey(_ key: String) throws {
        try SecureStore.set(
            key.trimmingCharacters(in: .whitespacesAndNewlines),
            service: service,
            account: account
        )
    }

    func clearUserAPIKey() {
        _ = SecureStore.remove(service: service, account: account)
    }

    // MARK: Key loading (internal so other files can call it)

    func loadKey() throws -> String {
        // Non-optional get()
        let raw = try SecureStore.get(service: service, account: account)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "AIClient", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "OpenAI key is empty"])
        }
        return trimmed
    }

    // MARK: Chat completions

    func complete(prompt: String, maxTokens: Int = 200) async throws -> String {
        guard isConfigured else { return fallback(prompt: prompt) }

        let apiKey = try loadKey()

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = ChatRequest(
            model: UserDefaults.standard.string(forKey: "ai.model") ?? "gpt-4o-mini",
            messages: [
                .init(role: "system",
                      content: "You are a concise assistant embedded in a comics cataloging app. Be brief and helpful."),
                .init(role: "user", content: prompt)
            ],
            max_tokens: maxTokens
        )
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return fallback(prompt: prompt)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        if let text = decoded.choices.first?.message.content?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }
        return fallback(prompt: prompt)
    }

    // MARK: Quick auth test (used by AISettingsView)

    /// Small GET to /v1/models?limit=1 to verify the key.
    func quickAuthCheck(using keyOverride: String? = nil) async throws {
        // Normalize override; if empty, use stored key.
        let candidate = (keyOverride ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let keyToUse  = candidate.isEmpty ? (try loadKey()) : candidate

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/models?limit=1")!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(keyToUse)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "AIClient", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "OpenAI rejected the key"])
        }
    }

    // MARK: Local fallback text
    private func fallback(prompt: String) -> String {
        "AI is not configured. Quick local summary: \(prompt.prefix(160))"
    }
}

// MARK: - Wire types

private struct ChatRequest: Codable {
    struct Message: Codable {
        let role: String
        let content: String?
    }
    let model: String
    let messages: [Message]
    let max_tokens: Int
}

private struct ChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String?
        }
        let index: Int
        let message: Message
    }
    let choices: [Choice]
}
