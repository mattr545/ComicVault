//
//  AppSettingsView.swift
//  ComicVault
//
//  iOS 16+
//
//  Uses full CloudKit-aware settings when USE_CLOUDSYNC is enabled.
//  Adds Auto Price Tracking + Wishlist Watchlist controls.
//
//  Last updated on 11-08-25 by Atlas & GPT-5 Thinking
//

import SwiftUI
import CloudKit

#if USE_CLOUDSYNC

// MARK: - Keys

private let SNAP_RETENTION_KEY   = "SNAP_RETENTION_DAYS"
private let SNAP_USE_ICLOUD_KEY  = "useICloudSync"
private let METADATA_LOOKUP_KEY  = "settings.metadataLookup"

// MARK: - Helper types

private enum RetentionChoice: Int, CaseIterable, Identifiable {
    case d30 = 30, d60 = 60, d90 = 90, d365 = 365, lifetime = -1

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .d30:      return "30 Days"
        case .d60:      return "60 Days"
        case .d90:      return "90 Days (Recommended)"
        case .d365:     return "1 Year"
        case .lifetime: return "Lifetime"
        }
    }
}

private enum TestTimeout: Double, CaseIterable, Identifiable {
    case s2 = 2, s4 = 4, s8 = 8

    var id: Double { rawValue }
    var label: String { "\(Int(rawValue))s" }
}

// MARK: - View

struct AppSettingsView: View {
    @EnvironmentObject private var cloud: CloudSync
    @EnvironmentObject private var collectionVM: CollectionViewModel

    @AppStorage(SNAP_USE_ICLOUD_KEY)  private var useICloudSync: Bool = true
    @AppStorage(SNAP_RETENTION_KEY)   private var retentionDays: Int = 90
    @AppStorage(METADATA_LOOKUP_KEY)  private var metadataEnabled: Bool = false
    @AppStorage("app.appearance")     private var appearanceRaw: String = AppAppearance.system.rawValue
    @AppStorage(PriceService.freqKey) private var autoFreqRaw: String = PriceService.AutoFrequency.weekly.rawValue
    @AppStorage(WishlistViewModel.autoEstimatesKey) private var wishlistAutoEstimates: Bool = true
    @AppStorage(WishlistViewModel.targetAlertsKey)  private var wishlistTargetAlerts: Bool = true

    @State private var testTimeout: TestTimeout = .s2

    var body: some View {
        Form {

            // Appearance
            Section(header: Text("Appearance")) {
                NavigationLink(destination: AppearanceView()) {
                    HStack {
                        Label("Appearance", systemImage: "sun.max")
                        Spacer()
                        Text(currentAppearanceLabel)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // AI Assistant
            Section(header: Text("AI Assistant")) {
                NavigationLink(destination: AISettingsView()) {
                    Label("AI Settings (OpenAI)", systemImage: "sparkles")
                }
                Text("Configure AI features like Add/Edit suggestions, value estimates, and trend explanations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Online Metadata
            Section(header: Text("Online Metadata")) {
                Toggle("Enable ComicVine lookups", isOn: $metadataEnabled)
                    .onChange(of: metadataEnabled) { _ in Haptics.tap() }

                if !metadataEnabled {
                    Text("Recommendation: turn this on to auto-suggest titles, issues, and covers.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                NavigationLink(destination: AddComicVineKeyView()) {
                    Label("Add API Key", systemImage: "key.fill")
                }

                HStack {
                    Text("Test Timeout")
                    Spacer()
                    Picker("", selection: $testTimeout) {
                        ForEach(TestTimeout.allCases) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }
                .accessibilityElement(children: .combine)
            }

            // Auto Price Tracking (owned collection)
            Section(
                header: Text("Auto Price Tracking"),
                footer: Text("Runs for your owned collection when you open or return to the app. Uses the Local Estimator by default; can be swapped to GoCollect/eBay later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            ) {
                Picker("Frequency", selection: $autoFreqRaw) {
                    ForEach(PriceService.AutoFrequency.allCases) { f in
                        Text(f.label).tag(f.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Text(autoRunDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Wishlist Watchlist
            Section(
                header: Text("Wishlist Watchlist"),
                footer: Text("Auto-estimates wishlist items and can alert you when an estimated price is at or below your target. Real-market providers can be added later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            ) {
                Toggle("Show estimated prices", isOn: $wishlistAutoEstimates)
                Toggle("Enable target price alerts", isOn: $wishlistTargetAlerts)
            }

            // iCloud Sync
            Section(
                header: Text("iCloud Sync"),
                footer: Text("ComicVault syncs via your private iCloud account. No data is shared with anyone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            ) {
                HStack {
                    Label("Account", systemImage: "icloud")
                    Spacer()
                    Text(accountStatusLabel(cloud.accountStatus))
                        .foregroundStyle(statusColor(cloud.accountStatus))
                }

                HStack {
                    Label("Last Pull", systemImage: "clock.arrow.circlepath")
                    Spacer()
                    Text(lastPullText())
                        .foregroundStyle(.secondary)
                }

                if cloud.isSyncing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Syncing…").font(.subheadline)
                    }
                    .accessibilityLabel("iCloud syncing in progress")
                }

                Button {
                    Task { await CloudSync.shared.pullRemoteChanges(into: collectionVM) }
                } label: {
                    Label("Pull Now", systemImage: "arrow.clockwise")
                }
                .disabled(cloud.accountStatus != .available)
            }

            // Storage & Snapshots
            Section(header: Text("Storage & Snapshots")) {
                Toggle("Sync snapshots via iCloud", isOn: $useICloudSync)
                Text("Stores daily snapshot files in your private iCloud Drive when enabled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Snapshot Retention
            Section(header: Text("Snapshot Retention")) {
                Picker(
                    "Keep Snapshots For",
                    selection: Binding(
                        get: { choiceFor(days: retentionDays) },
                        set: { newChoice in
                            retentionDays = newChoice.rawValue
                            if newChoice == .lifetime {
                                UserDefaults.standard.removeObject(forKey: SNAP_RETENTION_KEY)
                            } else {
                                UserDefaults.standard.set(newChoice.rawValue, forKey: SNAP_RETENTION_KEY)
                            }
                            Haptics.tap()
                        }
                    )
                ) {
                    ForEach(RetentionChoice.allCases) { c in
                        Text(c.label).tag(c)
                    }
                }
                .pickerStyle(.inline)

                Text("Recommended: 90 days. Snapshots prune automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .task { await cloud.refreshAccountStatus() }
    }

    // MARK: - Helpers

    private var currentAppearanceLabel: String {
        (AppAppearance(rawValue: appearanceRaw) ?? .system).label
    }

    private var autoFrequency: PriceService.AutoFrequency {
        PriceService.AutoFrequency(rawValue: autoFreqRaw) ?? .weekly
    }

    private var autoRunDescription: String {
        if autoFrequency == .off {
            return "Automatic tracking is off. You can still run bulk estimates manually."
        }
        if let last = PriceService.lastAutoRun {
            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .short
            let since = rel.localizedString(for: last, relativeTo: Date())
            return "\(autoFrequency.label) • Last run \(since)."
        } else {
            return "\(autoFrequency.label) • First run will occur next time you open ComicVault."
        }
    }

    private func choiceFor(days: Int) -> RetentionChoice {
        RetentionChoice(rawValue: days) ?? .d90
    }

    private func lastPullText() -> String {
        if let d = cloud.lastPullDate() {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            return f.string(from: d)
        }
        return "—"
    }

    private func accountStatusLabel(_ s: CKAccountStatus) -> String {
        switch s {
        case .available:              return "Available"
        case .noAccount:              return "No Account"
        case .restricted:             return "Restricted"
        case .couldNotDetermine:      return "Unknown"
        case .temporarilyUnavailable: return "Temporarily Unavailable"
        @unknown default:             return "Unknown"
        }
    }

    private func statusColor(_ s: CKAccountStatus) -> Color {
        switch s {
        case .available:              return .green
        case .noAccount, .restricted: return .orange
        case .couldNotDetermine,
             .temporarilyUnavailable: return .secondary
        @unknown default:             return .secondary
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AppSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AppSettingsView()
                .environmentObject(CloudSync.shared)
                .environmentObject(CollectionViewModel())
        }
    }
}
#endif

#else

// MARK: - Non-CloudSync version

struct AppSettingsView: View {
    @AppStorage(PriceService.freqKey) private var autoFreqRaw: String = PriceService.AutoFrequency.weekly.rawValue
    @AppStorage(WishlistViewModel.autoEstimatesKey) private var wishlistAutoEstimates: Bool = true
    @AppStorage(WishlistViewModel.targetAlertsKey)  private var wishlistTargetAlerts: Bool = true

    var body: some View {
        Form {
            Section(
                header: Text("Auto Price Tracking"),
                footer: Text("Runs for your owned collection when you open or return to the app using the Local Estimator.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            ) {
                Picker("Frequency", selection: $autoFreqRaw) {
                    ForEach(PriceService.AutoFrequency.allCases) { f in
                        Text(f.label).tag(f.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Text(autoRunDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(
                header: Text("Wishlist Watchlist"),
                footer: Text("Auto-estimates wishlist items and can alert you when an estimated price is at or below your target.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            ) {
                Toggle("Show estimated prices", isOn: $wishlistAutoEstimates)
                Toggle("Enable target price alerts", isOn: $wishlistTargetAlerts)
            }

            Section("iCloud Sync") {
                Text("iCloud features are disabled in this build.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }

    private var autoFrequency: PriceService.AutoFrequency {
        PriceService.AutoFrequency(rawValue: autoFreqRaw) ?? .weekly
    }

    private var autoRunDescription: String {
        if autoFrequency == .off {
            return "Automatic tracking is off. You can still run bulk estimates manually."
        }
        if let last = PriceService.lastAutoRun {
            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .short
            let since = rel.localizedString(for: last, relativeTo: Date())
            return "\(autoFrequency.label) • Last run \(since)."
        } else {
            return "\(autoFrequency.label) • First run will occur next time you open ComicVault."
        }
    }
}

#endif
