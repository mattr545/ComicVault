//
//  AppearanceView.swift
//  ComicVault
//
//  File created on 10/18/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: UI for selecting ComicVault appearance and theme options.
//
//  Running Edit Log
//  - 10-22-25: Simple theme picker (System / Light / Dark) using @AppStorage.
//
//  NOTES
//  This saves the appearance choice in UserDefaults so the app can apply it at launch.
//  Default is System. App-wide application is typically done at the root (e.g., App struct)
//  by reading this same key and setting .preferredColorScheme accordingly.
//

import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System (Default)"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

struct AppearanceView: View {
    @AppStorage("app.appearance") private var stored: String = AppAppearance.system.rawValue

    private var selection: Binding<AppAppearance> {
        Binding<AppAppearance>(
            get: { AppAppearance(rawValue: stored) ?? .system },
            set: { stored = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Theme", selection: selection) {
                    ForEach(AppAppearance.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.inline)

                Text("The app follows your system appearance by default. Choose Light or Dark to override.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationView { AppearanceView() }
        .tint(Theme.brandPrimary)
}
