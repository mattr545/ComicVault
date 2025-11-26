//
//  LaunchView.swift
//  ComicVault
//
//  File created on 10/15/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Splash/intro experience shown on first launch.
//
//  Running Edit Log
//  - 10-22-25: Hybrid splash (button immediately active + 4s auto-advance).
//  - 10-22-25: Logo now scales to ~80% of screen width with safe max.
//  - 10-22-25: Keeps CryptoComics logo + subtitle as discussed.
//  - 10-23-25: Fixed logo visibility (moved to dedicated AppLogo asset).
//  - 10-23-25: Adjusted layout — ComicVault logo centered in red box area,
//              CryptoComics logo and subtitle moved lower above the button.
//
//  NOTES
//  - “AppIcon” sets cannot be loaded as images. Use a normal ImageSet named “AppLogo”.
//  - The Continue button is active immediately and auto-fires after ~4 seconds.
//

import SwiftUI
import UIKit

struct LaunchView: View {
    /// Called when the splash should proceed into the app.
    let onContinue: () -> Void

    @State private var autoAdvanceFired = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer(minLength: 40)

                // --- TOP LOGO AREA (red box in your mockup) ---
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 480)
                    .padding(.horizontal, 24)
                    .frame(height: 200, alignment: .center)

                // App name text
                Text("ComicVault")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor) // was Theme.brandPrimary
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 40)

                // --- CryptoComics attribution block (lowered) ---
                VStack(spacing: 8) {
                    Image("CryptoComicsLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140)
                        .accessibilityHidden(true)

                    Text("Brought to you by CryptoComics")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Continue button (active immediately)
                Button(action: proceed) {
                    Text("CONTINUE")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor) // was Theme.brandPrimary
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            // Auto-advance after ~4 seconds if user doesn’t tap
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                guard !autoAdvanceFired else { return }
                autoAdvanceFired = true
                onContinue()
            }
        }
    }

    // MARK: - Private Helpers

    private func proceed() {
        guard !autoAdvanceFired else { return }
        autoAdvanceFired = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred() // was Haptics.tap()
        onContinue()
    }
}

// MARK: - Preview

@available(iOS 16.0, *)
#Preview {
    LaunchView { }
        .tint(Color.accentColor)
}
