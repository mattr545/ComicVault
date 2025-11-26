//
//  AISettingsView.swift
//  ComicVault
//
//  File created on 10/29/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Settings screen for enabling AI, managing API keys, and choosing models.
//
//

import SwiftUI

private let AI_ENABLED_KEY = "ai.enabled"
private let AI_MODEL_KEY   = "ai.model"
private let AI_PRIV_KEY    = "com.comicvault.ai.openai"   // Keychain service
private let AI_PRIV_ACCT   = "user_api_key"               // Keychain account

struct AISettingsView: View {
    @AppStorage(AI_ENABLED_KEY) private var aiEnabled: Bool = false
    @AppStorage(AI_MODEL_KEY)   private var selectedModel: String = "gpt-4o-mini"

    @State private var apiKey: String = (try? SecureStore.get(service: AI_PRIV_KEY, account: AI_PRIV_ACCT)) ?? ""
    @State private var isTesting = false
    @State private var testResult: String?

    // Minimal model list. You can expand later.
    private let models = [
        "gpt-4o-mini",
        "gpt-4o",
        "o3-mini"
    ]

    var body: some View {
        Form {
            Section(header: Text("AI Assist")) {
                Toggle("Enable AI Assist", isOn: $aiEnabled)
                Text("When enabled, the Add/Edit screen shows suggestions powered by your OpenAI key.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("OpenAI API Key")) {
                SecureField("sk-...", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                HStack {
                    Button("Save Key") { saveKey() }
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()

                    Button {
                        Task { await testKey() }
                    } label: {
                        if isTesting { ProgressView() } else { Text("Test Key") }
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting)
                }

                if let msg = testResult {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Link("Get an OpenAI API key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .font(.callout.weight(.semibold))
            }

            Section(header: Text("Model")) {
                Picker("Preferred Model", selection: $selectedModel) {
                    ForEach(models, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                Text("You can change this anytime. Lighter models are cheaper and faster.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Privacy")) {
                Text("Your API key is stored securely in the iOS Keychain. Prompts are sent directly from the app to OpenAI using your key. We don’t collect your data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("AI Settings")
        .tint(Theme.brandPrimary)
        .onDisappear { saveKey() }
    }

    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmed.isEmpty {
                _ = SecureStore.remove(service: AI_PRIV_KEY, account: AI_PRIV_ACCT)
            } else {
                try SecureStore.set(trimmed, service: AI_PRIV_KEY, account: AI_PRIV_ACCT)
            }
            testResult = "Saved."
        } catch {
            testResult = "Couldn’t save key (\(error.localizedDescription))."
        }
    }

    private func testKey() async {
        isTesting = true
        testResult = "Testing key…"
        defer { isTesting = false }

        // This will be implemented in AIClient.swift (next files).
        do {
            try await AIClient.shared.quickAuthCheck(using: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            testResult = "Key looks valid."
        } catch {
            testResult = "Test failed: \(error.localizedDescription)"
        }
    }
}
