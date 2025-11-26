//
//  PriceAlertManager.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Manages local notifications for significant value changes.
//
//  Running Edit Log
//  - 10-27-25: Initial threshold + notification logic.
//  - 11-07-25: Provider-aware alert body support.
//  - 11-08-25: Header normalization.
//
//

import Foundation
import UserNotifications

@available(iOS 16.0, *)
final class PriceAlertManager {

    static let shared = PriceAlertManager()

    // UserDefaults keys
    private let enabledKey       = "alerts.enabled"
    private let pctKey           = "alerts.threshold.percent"
    private let minAbsKey        = "alerts.threshold.absolute"
    private let requestedAuthKey = "alerts.requestedAuth"

    // Defaults
    private let defaultPercent: Double  = 20.0
    private let defaultAbsolute: Double = 25.0

    // MARK: Stored settings

    var alertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    var percentThreshold: Double {
        get { UserDefaults.standard.object(forKey: pctKey) as? Double ?? defaultPercent }
        set { UserDefaults.standard.set(max(0, newValue), forKey: pctKey) }
    }

    var absoluteThreshold: Double {
        get { UserDefaults.standard.object(forKey: minAbsKey) as? Double ?? defaultAbsolute }
        set { UserDefaults.standard.set(max(0, newValue), forKey: minAbsKey) }
    }

    // MARK: Public API

    func checkAndNotify(comic: Comic, old oldValue: Double?, new newValue: Double) {
        checkAndNotify(comic: comic, old: oldValue, new: newValue, provider: nil)
    }

    func checkAndNotify(
        comic: Comic,
        old oldValue: Double?,
        new newValue: Double,
        provider: String?
    ) {
        guard alertsEnabled else { return }
        guard let old = oldValue, old > 0 else { return }

        let delta    = newValue - old
        let absDelta = abs(delta)
        let pct      = (absDelta / old) * 100.0

        guard absDelta >= absoluteThreshold || pct >= percentThreshold else { return }

        var body = String(
            format: "%@%.2f change (%.1f%%) — now %@",
            delta >= 0 ? "+" : "-",
            absDelta,
            pct,
            newValue.formatted(.currency(code: "USD"))
        )

        if let provider, !provider.isEmpty {
            body += " via \(provider)"
        }

        notifyLocal(
            title: "Price \(delta >= 0 ? "↑" : "↓") for \(comic.displayTitle)",
            body: body
        )
    }

    // MARK: Local notifications

    private func notifyLocal(title: String, body: String) {
        let center = UNUserNotificationCenter.current()

        if UserDefaults.standard.object(forKey: requestedAuthKey) as? Bool != true {
            UserDefaults.standard.set(true, forKey: requestedAuthKey)
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let req = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        center.add(req, withCompletionHandler: nil)
    }
}

// MARK: - Compatibility

@available(iOS 16.0, *)
extension PriceAlertManager {
    @inline(__always)
    func checkAndNotify(comic: Comic, oldValue: Double?, newValue: Double) {
        checkAndNotify(comic: comic, old: oldValue, new: newValue, provider: nil)
    }

    @inline(__always)
    func checkAndNotify(for comic: Comic, old oldValue: Double?, new newValue: Double) {
        checkAndNotify(comic: comic, old: oldValue, new: newValue, provider: nil)
    }

    @inline(__always)
    func checkAndNotify(for comic: Comic, new newValue: Double, old oldValue: Double?) {
        checkAndNotify(comic: comic, old: oldValue, new: newValue, provider: nil)
    }

    @inline(__always)
    func checkAndNotify(comic: Comic, newValue: Double, oldValue: Double?) {
        checkAndNotify(comic: comic, old: oldValue, new: newValue, provider: nil)
    }
}

@available(iOS 16.0, *)
typealias PriceAlerts = PriceAlertManager
