//
//  CloudKitAvailability.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Utility to check and represent CloudKit account/status availability.
//
//  Running Edit Log
//  - Rebuilt on 11/04/25 due to so many errors using the Cloudkit.
//

import Foundation
import SwiftUI
import Combine

#if USE_CLOUDSYNC
import CloudKit

/// Watches iCloud account availability and exposes a simple state.
/// Use `ICloudStatusBanner` to display a one-line notice when iCloud is unavailable.
@MainActor
final class CloudKitAvailability: ObservableObject {
    enum State: Equatable {
        case unknown
        case available
        case noAccount
        case restricted
        case couldNotDetermine(Error)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown),
                 (.available, .available),
                 (.noAccount, .noAccount),
                 (.restricted, .restricted):
                return true
            case let (.couldNotDetermine(e1), .couldNotDetermine(e2)):
                let n1 = e1 as NSError, n2 = e2 as NSError
                return n1.domain == n2.domain && n1.code == n2.code
            default:
                return false
            }
        }
    }

    @Published private(set) var state: State = .unknown
    private let container: CKContainer
    private var timer: AnyCancellable?

    init(container: CKContainer = .default()) {
        self.container = container
        Task { await refresh() }
        // Passive polling to catch sign-in changes outside the app.
        timer = Timer.publish(every: 180, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
    }

    deinit { timer?.cancel() }

    /// Manually re-check iCloud account status.
    func refresh() async {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:               state = .available
            case .noAccount:               state = .noAccount
            case .restricted:              state = .restricted
            case .couldNotDetermine:
                state = .couldNotDetermine(NSError(
                    domain: "CloudKit", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not determine iCloud status"]
                ))
            @unknown default:
                state = .couldNotDetermine(NSError(
                    domain: "CloudKit", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown iCloud status"]
                ))
            }
        } catch {
            state = .couldNotDetermine(error)
        }
    }

    var isAvailable: Bool {
        if case .available = state { return true }
        return false
    }
}

/// A thin banner that tells the user when iCloud is not available.
/// Place this at the top of a screen, for example inside `List` or above content.
struct ICloudStatusBanner: View {
    @ObservedObject var availability: CloudKitAvailability

    var body: some View {
        switch availability.state {
        case .available, .unknown:
            EmptyView()
        case .noAccount:
            Banner(text: "iCloud is not signed in. Changes will not sync until you sign in to iCloud.", systemImage: "icloud.slash")
        case .restricted:
            Banner(text: "iCloud is restricted on this device. Changes will not sync.", systemImage: "exclamationmark.triangle")
        case .couldNotDetermine:
            Banner(text: "Could not check iCloud. Pull to refresh or try again later.", systemImage: "exclamationmark.triangle")
        }
    }

    private struct Banner: View {
        let text: String
        let systemImage: String
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(text)
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.primary)
            .background(Color.yellow.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        }
    }
}

#else
// MARK: - No-cloud stub (builds when USE_CLOUDSYNC is not defined)

@MainActor
final class CloudKitAvailability: ObservableObject {
    enum State: Equatable { case unknown, unavailable }

    @Published private(set) var state: State = .unavailable

    init() {}

    func refresh() async { /* no-op */ }

    var isAvailable: Bool { false }
}

struct ICloudStatusBanner: View {
    @ObservedObject var availability: CloudKitAvailability
    var body: some View { EmptyView() }
}
#endif

// MARK: - Convenience EnvironmentKey (works in both modes)

private struct CloudKitAvailabilityKey: EnvironmentKey {
    static let defaultValue = CloudKitAvailability()
}

extension EnvironmentValues {
    var cloudKitAvailability: CloudKitAvailability {
        get { self[CloudKitAvailabilityKey.self] }
        set { self[CloudKitAvailabilityKey.self] = newValue }
    }
}
