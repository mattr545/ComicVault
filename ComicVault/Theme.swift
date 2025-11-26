//
//  Theme.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Design tokens, brand colors, and reusable view helpers.
//
//  Running Edit Log
//  - 10-22-25: Introduced brand palette and helpers.
//  - 11-08-25: Header normalization.
//
//

import SwiftUI

// MARK: - Design Tokens

enum Theme {
    // Brand palette (from CV logo)
    static let brandPrimary = Color(hex: "#0AA5A3")   // teal / greenish-blue
    static let brandAccent  = Color(hex: "#FFD000")   // gold outline

    // Surfaces (safe in light/dark)
    static let surface    = Color(.systemBackground)
    static let surfaceAlt = Color(.secondarySystemBackground)
    static let outline    = Color(.quaternaryLabel)

    // Semantic tints (general purpose)
    static let infoTint    = Color.blue
    static let successTint = Color.green
    static let warnTint    = Color.orange
    static let dangerTint  = Color.red

    // Scales
    enum Spacing: CGFloat { case xs = 6, sm = 10, md = 14, lg = 20, xl = 28 }
    enum Radius:  CGFloat { case sm = 8, md = 12, lg = 16, xl = 24 }

    // Subtle card shadow
    static func cardShadow() -> some View { ShadowStyle() }

    private struct ShadowStyle: View {
        var body: some View {
            Rectangle()
                .fill(.clear)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                .hidden()
        }
    }
}

// MARK: - Reusable View Helpers

extension View {
    /// Card container with surface + 1pt outline.
    func cardBackground(corner: Theme.Radius = .lg) -> some View {
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: corner.rawValue)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: corner.rawValue)
                            .stroke(Theme.outline)
                    )
            )
    }

    /// Soft, reusable drop shadow.
    func softCardShadow() -> some View {
        self.shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    /// Brand header style (use for screen titles or section headers).
    func cvHeader(_ size: Font = .title2, weight: Font.Weight = .bold) -> some View {
        self
            .font(size)
            .font(.system(size: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: weight))
            .foregroundStyle(Theme.brandPrimary)
    }

    /// Brand icon style (SF Symbols + brand colors).
    /// Example:
    ///    Image(systemName: "sparkles").cvIcon()
    ///    Image(systemName: "star.fill").cvIcon(size: 28, useGoldHighlight: true)
    func cvIcon(size: CGFloat = 20, useGoldHighlight: Bool = false) -> some View {
        modifier(CVIconModifier(size: size, gold: useGoldHighlight))
    }
}

// Concrete modifier avoids overload ambiguity in `.foregroundStyle(...)`
private struct CVIconModifier: ViewModifier {
    let size: CGFloat
    let gold: Bool

    func body(content: Content) -> some View {
        Group {
            if gold {
                content
                    .font(.system(size: size, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Theme.brandPrimary, Theme.brandAccent)
            } else {
                content
                    .font(.system(size: size, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Theme.brandPrimary)
            }
        }
    }
}

// MARK: - Hex helper

private extension Color {
    /// Initialize from hex like "#0AA5A3" or "0AA5A3".
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var n: UInt64 = 0
        Scanner(string: s).scanHexInt64(&n)

        let r, g, b, a: Double
        switch s.count {
        case 3: // RGB (12-bit)
            r = Double((n >> 8) & 0xF) / 15.0
            g = Double((n >> 4) & 0xF) / 15.0
            b = Double(n & 0xF) / 15.0
            a = 1
        case 6: // RRGGBB (24-bit)
            r = Double((n >> 16) & 0xFF) / 255.0
            g = Double((n >> 8) & 0xFF) / 255.0
            b = Double(n & 0xFF) / 255.0
            a = 1
        case 8: // AARRGGBB (32-bit)
            a = Double((n >> 24) & 0xFF) / 255.0
            r = Double((n >> 16) & 0xFF) / 255.0
            g = Double((n >> 8) & 0xFF) / 255.0
            b = Double(n & 0xFF) / 255.0
        default:
            r = 0; g = 0.65; b = 0.62; a = 1 // teal-ish fallback
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Theme.Spacing.lg.rawValue) {
        Text("ComicVault").cvHeader(.largeTitle)

        HStack(spacing: 16) {
            Image(systemName: "sparkles").cvIcon(size: 28, useGoldHighlight: true)
            Image(systemName: "chart.line.uptrend.xyaxis").cvIcon(size: 28)
            Image(systemName: "shippingbox").cvIcon(size: 28)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Card Title").cvHeader(.headline, weight: .semibold)
            Text("This is a themed card using the brand palette.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardBackground()
        .softCardShadow()
    }
    .padding()
    .background(Theme.surfaceAlt.ignoresSafeArea())
    .tint(Theme.brandPrimary)
}
