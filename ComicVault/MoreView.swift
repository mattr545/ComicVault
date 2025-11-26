//
//  MoreView.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Tab with settings, help, backups, and community links.
//

import SwiftUI

struct MoreView: View {
    // We need the live collection so BackupCenterView can export current comics.
    @EnvironmentObject private var collectionVM: CollectionViewModel
    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var useInlineTitle: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #else
        // iPad / large layouts prefer inline for a more native look
        return hSizeClass == .regular
        #endif
    }

    var body: some View {
        NavigationView {
            List {
                // MARK: - Insights
                Section("Insights") {
                    NavigationLink {
                        TrendsView()
                            .environmentObject(collectionVM)
                    } label: {
                        Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                    }
                }

                // MARK: - Settings
                Section("Settings") {
                    NavigationLink {
                        AnyView(ComicVault.AppSettingsView())
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }

                // MARK: - Backup & Data
                Section("Backup & Data") {
                    NavigationLink {
                        BackupCenterView()
                            .environmentObject(collectionVM)
                    } label: {
                        Label("Backup Center", systemImage: "arrow.up.doc")
                    }
                }

                // MARK: - Help & Support
                Section("Help & Support") {
                    NavigationLink {
                        TipsTricksView()
                    } label: {
                        Label("Tips & Tricks", systemImage: "lightbulb")
                    }

                    Button {
                        openURL("mailto:support@cryptocomics.com")
                    } label: {
                        Label("Contact Support", systemImage: "questionmark.circle")
                    }
                }

                // MARK: - About
                Section("About") {
                    NavigationLink {
                        OurStoryView()
                    } label: {
                        Label("Our Story", systemImage: "book.closed")
                    }

                    HStack {
                        Label("Version", systemImage: "number")
                        Spacer()
                        Text(appVersionString())
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: - Legal
                Section("Legal") {
                    Button {
                        openURL("https://docs.google.com/document/d/1zFUKYV2bjK1IdTZ4vemPk3kKjnSEzzFZlRo8e8B7YVU/edit?usp=sharing")
                    } label: {
                        Label("Privacy Policy", systemImage: "lock.shield")
                    }

                    Button {
                        openURL("https://docs.google.com/document/d/11doCUOdH-e1waskiKAggI0otMzI-G_7lGnxnV-eTy30/edit?usp=sharing")
                    } label: {
                        Label("Terms of Service", systemImage: "doc.text")
                    }

                    HStack {
                        Text("Last updated:")
                        Spacer()
                        Text("October 2025")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: - Feedback
                Section("Feedback") {
                    Button {
                        openURL("mailto:support@cryptocomics.com?subject=ComicVault%20Feedback")
                    } label: {
                        Label("Send Feedback", systemImage: "paperplane.fill")
                    }
                }

                // MARK: - Community Links
                Section("Community Links") {
                    Button { openURL("https://cryptocomics.com/dashboard") } label: {
                        Label("CryptoComics Marketplace", image: "cryptocomics")
                            .labelStyle(.titleAndIcon)
                            .imageScale(.large)
                            .font(.title3)
                    }
                    Button { openURL("https://www.linkedin.com/company/cryptocomicsmarketplace") } label: {
                        Label("LinkedIn", image: "linkedin")
                            .labelStyle(.titleAndIcon)
                            .imageScale(.large)
                            .font(.title3)
                    }
                    Button { openURL("https://discord.com/invite/yRTTMAJQRX") } label: {
                        Label("Discord", image: "discord")
                            .labelStyle(.titleAndIcon)
                            .imageScale(.large)
                            .font(.title3)
                    }
                    Button { openURL("https://x.com/CryptocomicsM/") } label: {
                        Label("X (Twitter)", image: "x")
                            .labelStyle(.titleAndIcon)
                            .imageScale(.large)
                            .font(.title3)
                    }
                    Button { openURL("https://www.facebook.com/CryptoComicsMarketplace/") } label: {
                        Label("Facebook", image: "facebook")
                            .labelStyle(.titleAndIcon)
                            .imageScale(.large)
                            .font(.title3)
                    }
                    Button { openURL("https://www.instagram.com/cryptocomicsmarketplace/") } label: {
                        Label("Instagram", image: "instagram")
                            .labelStyle(.titleAndIcon)
                            .imageScale(.large)
                            .font(.title3)
                    }
                    Button { openURL("https://www.youtube.com/c/CryptoComicsMarketplace/") } label: {
                        Label("YouTube", image: "youtube")
                            .labelStyle(.titleAndIcon)
                            .imageScale(.large)
                            .font(.title3)
                    }
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(useInlineTitle ? .inline : .large)
        }
    }

    // MARK: - Helpers
    private func openURL(_ s: String) {
        guard let url = URL(string: s) else { return }
        UIApplication.shared.open(url)
    }

    private func appVersionString() -> String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }
}

#Preview {
    MoreView().environmentObject(CollectionViewModel())
}
