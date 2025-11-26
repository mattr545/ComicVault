//
//  SyncStatusBadge.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Small badge view that visualizes SyncStatus in the UI.
//
//  Running Edit Log
//              -  Env/Singleton-driven: `SyncStatusBadge` (watches CloudSync.shared.isSyncing).
//              - Value-driven: `SyncStatusBadgeManual` (renders a passed-in SyncStatus).
//              - A backward-compatible `typealias SyncBadgeView = SyncStatusBadgeManual` is provided, so existing `SyncBadgeView(status:)` usages keep compiling.
//
//  Notes:
//  - `SyncStatusBadge` no longer crashes if no EnvironmentObject is set; it uses
//    `CloudSync.shared` by default, matching existing call sites safely.
//

import SwiftUI

// MARK: - Visual style switch

enum SyncBadgeStyle {
    /// Compact, inline row (matches the old SyncBadgeView look).
    case inline
    /// Padded capsule with thinMaterial background (matches the old SyncStatusBadge look).
    case capsule
}

// MARK: - ENV/SHARED–DRIVEN BADGE
struct SyncStatusBadge: View {
    @ObservedObject private var cloud: CloudSync
    private let style: SyncBadgeStyle

    /// Defaults use CloudSync.shared so it's safe even when no EnvironmentObject is injected.
    init(style: SyncBadgeStyle = .capsule, cloud: CloudSync? = nil) {
        self.style = style
        if let cloud = cloud {
            self.cloud = cloud
        } else {
            // Access safely on main actor to silence isolation warning
            self.cloud = MainActor.assumeIsolated {
                CloudSync.shared
            }
        }
    }

    var body: some View {
        Group {
            if cloud.isSyncing {
                label(for: .syncing, style: style)
                    .accessibilityLabel("iCloud syncing in progress")
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: cloud.isSyncing)
    }
}

// MARK: - VALUE-DRIVEN BADGE (replaces old SyncBadgeView(status:))

struct SyncStatusBadgeManual: View {
    let status: SyncStatus
    var style: SyncBadgeStyle = .inline
    var errorHelpText: String? = nil   // optional: tooltip-style help for error

    var body: some View {
        switch status {
        case .idle:
            EmptyView()
        case .syncing:
            label(for: .syncing, style: style)
        case .error(let message):
            label(for: .error, style: style)
                .help(errorHelpText ?? message)
        }
    }
}

// Backward-compat: existing code `SyncBadgeView(status:)` compiles without changes.
typealias SyncBadgeView = SyncStatusBadgeManual

// MARK: - Rendering

private enum _ResolvedState { case syncing, error }

@ViewBuilder
private func label(for state: _ResolvedState, style: SyncBadgeStyle) -> some View {
    let base = HStack(spacing: 6) {
        switch state {
        case .syncing:
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(style == .capsule ? 0.8 : 1.0)
            Text("Syncing…")
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Sync Error")
        }
    }
    .font(.footnote.weight(.semibold))

    switch state {
    case .syncing:
        switch style {
        case .inline:
            base.foregroundStyle(.secondary)
        case .capsule:
            base
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
                .foregroundStyle(.primary)
        }
    case .error:
        switch style {
        case .inline:
            base.foregroundStyle(.orange)
        case .capsule:
            base
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
                .foregroundStyle(.orange)
        }
    }
}
