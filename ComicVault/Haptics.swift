//
//  Haptics.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Centralized haptic utilities and global ButtonStyle.
//
//  Running Edit Log
//  - 11-03-25: Mac-safe haptics + sensoryFeedback wrapper.
//  - 11-08-25: Header normalization.
//
//

import SwiftUI
import UIKit

enum Haptics {

    /// True on iPhone/iPad; false when running on macOS (both “Designed for iPad” and Catalyst).
    static var isHapticsSupported: Bool {
        if ProcessInfo.processInfo.isiOSAppOnMac { return false }
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return true
        #endif
    }

    static func tap(weight: UIImpactFeedbackGenerator.FeedbackStyle = .heavy) {
        guard isHapticsSupported else { return }
        let gen = UIImpactFeedbackGenerator(style: weight)
        gen.prepare()
        gen.impactOccurred()
    }

    static func success() {
        guard isHapticsSupported else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }

    static func warning() {
        guard isHapticsSupported else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.warning)
    }

    static func error() {
        guard isHapticsSupported else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.error)
    }
}

/// A universal ButtonStyle that emits a firm impact when the button is pressed.
/// Apply at the app root so all Buttons inherit it automatically.
struct HapticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let scaled = configuration.isPressed ? 0.98 : 1.0

        if #available(iOS 17.0, *) {
            // iOS 17+: declarative sensoryFeedback
            return configuration.label
                .scaleEffect(scaled)
                .modifier(SensoryIfSupported(trigger: configuration.isPressed))
        } else {
            // iOS 16 fallback: manually tap on press changes
            return configuration.label
                .scaleEffect(scaled)
                .onChange(of: configuration.isPressed) { pressed in
                    if pressed { Haptics.tap() }
                }
        }
    }

    /// Wrap sensoryFeedback so we can guard it at runtime for Mac.
    @available(iOS 17.0, *)
    private struct SensoryIfSupported: ViewModifier {
        let trigger: Bool
        func body(content: Content) -> some View {
            if Haptics.isHapticsSupported {
                content.sensoryFeedback(.impact(weight: .heavy), trigger: trigger)
            } else {
                content
            }
        }
    }
}
